#include <ArduinoBLE.h>
#include <DynamixelShield.h>

// ####### BLE INIT - DO NOT CHANGE #################
BLEService bleService("19B10000-E8F2-537E-4F6C-D104768A1214"); // Bluetooth® Low Energy LED Service
// Bluetooth® Low Energy LED rx Characteristic - custom 128-bit UUID, read and writable by central
BLECharacteristic rxCharacteristic("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 10);
BLECharacteristic txCharacteristic("19B10002-E8F2-537E-4F6C-D104768A1214", BLEWrite | BLERead, 10);

// ####### END OF BLE INIT - DO NOT CHANGE #################

 
const uint8_t BROADCAST_ID = 254;
const float DYNAMIXEL_PROTOCOL_VERSION = 2.0;
const uint8_t DXL_ID_CNT = 5;
const uint8_t DXL_ID_LIST[DXL_ID_CNT] = {4,5,6,7,1};
const uint16_t user_pkt_buf_cap = 128;
uint8_t user_pkt_buf[user_pkt_buf_cap];

// Starting address of the Data to read; Present Position = 132
const uint16_t SR_START_ADDR = 132;
// Length of the Data to read; Length of Position data of X series is 4 byte
const uint16_t SR_ADDR_LEN = 4;
// Starting address of the Data to write; Goal Position = 116
const uint16_t SW_START_ADDR = 116;
// Length of the Data to write; Length of Position data of X series is 4 byte
const uint16_t SW_ADDR_LEN = 4;
typedef struct sr_data{
  int32_t present_position;
} __attribute__((packed)) sr_data_t;
typedef struct sw_data{
  int32_t goal_position;
} __attribute__((packed)) sw_data_t;


sr_data_t sr_data[DXL_ID_CNT];
DYNAMIXEL::InfoSyncReadInst_t sr_infos;
DYNAMIXEL::XELInfoSyncRead_t info_xels_sr[DXL_ID_CNT];

sw_data_t sw_data[DXL_ID_CNT];
DYNAMIXEL::InfoSyncWriteInst_t sw_infos;
DYNAMIXEL::XELInfoSyncWrite_t info_xels_sw[DXL_ID_CNT];

DynamixelShield dxl;

//This namespace is required to use DYNAMIXEL Control table item name definitions
using namespace ControlTableItem;

const uint8_t bottomL = 4;
const uint8_t bottomR = 5;
const uint8_t topL = 6;
const uint8_t topR = 7;
const uint8_t rotator = 1;

struct Motor {
  int id;          
  double position;
};

Motor motorStates[DXL_ID_CNT] = {
  {bottomL, 0}, // id, position
  {bottomR, 0},
  {topL, 0},
  {topR, 0},
  {rotator, 0}
};

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  Serial.begin(115200);
  dxl.begin(57600);
  dxl.setPortProtocolVersion(DYNAMIXEL_PROTOCOL_VERSION);
  initMotors();
  motorSetup();
  setupBLE();
}

void loop() {  
  BLE.poll();
  sendMotorData();
}

void returnToAbsolutePosition(int i) {
  int turn = motorStates[i].position / 4096; // integer division
  int feedGearInitPosition = 342;
  if (motorStates[i].position < 0) {
    turn -= 1;
  }
  int curPosInThisTurn = motorStates[i].position - turn * 4096;
  int goalPosition = motorStates[i].position;

  if (i == 0) {
    Serial.println(curPosInThisTurn);
    if (curPosInThisTurn >= 512 && curPosInThisTurn <= 4096) {
      goalPosition += 4096 - curPosInThisTurn - feedGearInitPosition;
    } else if (curPosInThisTurn >= 0 && curPosInThisTurn < 512) {
      goalPosition -= curPosInThisTurn + feedGearInitPosition;
    }
    // goalPosition += 4096 - curPosInThisTurn - feedGearInitPosition;

    Serial.println(goalPosition);
    Serial.println();
  }

  if (i == 2) {
    if (curPosInThisTurn >= 3580 && curPosInThisTurn <= 4096) {
      goalPosition += 4096 - curPosInThisTurn;
    } else if (curPosInThisTurn >= 0 && curPosInThisTurn < 3580) {
      goalPosition -= curPosInThisTurn;
    }
  }
  if (i == 1) {
    if (curPosInThisTurn >= 0 && curPosInThisTurn < 3580) {
      goalPosition -= curPosInThisTurn - feedGearInitPosition;
    } else if (curPosInThisTurn >= 3580 && curPosInThisTurn <= 4096) {
      goalPosition += 4096 - curPosInThisTurn + feedGearInitPosition;
    } 
  }

  if (i == 3) {
    if (curPosInThisTurn >= 0 && curPosInThisTurn < 686) {
      goalPosition -= curPosInThisTurn;
    } else if (curPosInThisTurn >= 686 && curPosInThisTurn <= 4096) {
      goalPosition += 4096 - curPosInThisTurn;
    } 
  }

  if (i == 4) { // rotator
    goalPosition = 0;
  }

  motorStates[i].position = goalPosition;
}

void setMotorSteps(int i, double stepCount, int dir_flag) {
  // arbitrary step-to-angle conversion: A single turn takes the values 
  // from 0 to 4096 and in multiturn it can take -1,048,575 ~ 1,048,575
  // 11.38: 1 degree = 11.38 position; 30: each tooth is 30 degrees for a 12-tooth gear, 27.69 for 13-tooth
  double angle = stepCount * 11.38;
  double step = angle * 27.69; //
  if (dir_flag == 1) {
    angle = -angle;
    step = -step;
  }
  if (i != 4) {
    motorStates[i].position += step;
  } else {
    motorStates[i].position += angle;
  }
}

void rxCharacteristicWritten(BLEDevice central, BLECharacteristic characteristic) {
  // central wrote new value to characteristic, update LED
  const uint8_t* msg = rxCharacteristic.value();
  bool all255 = true;
  for (int i = 0; i < 2*DXL_ID_CNT; i++) {
    Serial.print(msg[i]);
    if (msg[i] != 255) { all255 = false; } 
  } 
  Serial.println();
  if (all255) { // if receiving reset command
    resetMotors();
  } else { // step or absolute commands
    for (int i = 0; i < DXL_ID_CNT; i++) {
      int dir_flag = msg[2*i];  // 1 for negative, 0 for positive
      double angle = msg[2*i+1];
      if (angle == 254) { // absolute condition on GUI
        returnToAbsolutePosition(i); // command the motor to return to abs position
      } else {
        setMotorSteps(i, angle, dir_flag);
      }
    }
  }
  uint8_t i;

  // Insert a new Goal Position to the SyncWrite Packet
  for (i = 0; i < DXL_ID_CNT; i++) {
    sw_data[i].goal_position = motorStates[i].position;// this is the key
  }

  // Update the SyncWrite packet status
  sw_infos.is_info_changed = true;

  // Build a SyncWrite Packet and transmit to DYNAMIXEL
  if (dxl.syncWrite(&sw_infos) == true) {
    for(i = 0; i < sw_infos.xel_count; i++) {
    }
  } else {
    Serial.print("[SyncWrite] Fail, Lib error code: ");
    Serial.print(dxl.getLastLibErrCode());
  }
}

void sendMotorData() {
  byte byteArray[10];
  uint8_t i, recv_cnt;
  // Transmit predefined SyncRead instruction packet
  // and receive a status packet from each DYNAMIXEL
  recv_cnt = dxl.syncRead(&sr_infos);
  if (recv_cnt > 0) {
    for (i = 0; i < recv_cnt; i++){
      // Serial.print("  ID: ");
      // Serial.print(sr_infos.p_xels[i].id);
      
      // Serial.print(", Error: ");
      // Serial.println(sr_infos.p_xels[i].error);
      // Serial.print("\t Present Position: ");
      // Serial.println(sr_data[i].present_position);
      int cyclePosition = sr_data[i].present_position % 4096;

      byteArray[i * 2] = (byte)(cyclePosition >> 8);    // High byte of each integer
      byteArray[i * 2 + 1] = (byte)(cyclePosition & 0xFF); // Low byte of each integer
    }
  }
  txCharacteristic.writeValue(byteArray, sizeof(byteArray));
}

