#include <ArduinoBLE.h>
#include <DynamixelShield.h>

// ####### BLE INIT - DO NOT CHANGE #################
BLEService bleService("19B10000-E8F2-537E-4F6C-D104768A1214"); // Bluetooth® Low Energy LED Service
// Bluetooth® Low Energy LED rx Characteristic - custom 128-bit UUID, read and writable by central
BLECharacteristic rxCharacteristic("19B10001-E8F2-537E-4F6C-D104768A1214", BLERead | BLEWrite, 8);
// ####### END OF BLE INIT - DO NOT CHANGE #################

 
const uint8_t BROADCAST_ID = 254;
const float DYNAMIXEL_PROTOCOL_VERSION = 2.0;
const uint8_t DXL_ID_CNT = 4;
const uint8_t DXL_ID_LIST[DXL_ID_CNT] = {4,5,6,7};
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

struct Motor {
  int id;          
  double position;
};

Motor motorStates[DXL_ID_CNT] = {
  {bottomL, 0}, // id, position
  {bottomR, 0},
  {topL, 0},
  {topR, 0}
  // Add more motor control pins here if needed
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
}

void returnToAbsolutePosition(int i) {
  int currentPos = motorStates[i].position;
  int turn = motorStates[i].position / 4096;
  int goalPosition = turn * 4096;
  int prevTurnPos = turn * 4096;
  int nextTurnPos = (turn + 1) * 4096;
  if (currentPos < 0) {
    prevTurnPos = (turn-1) * 4096;
    nextTurnPos = turn * 4096;
  }
  int curPosInThisTurn = currentPos - turn * 4096;
  if (i == 2 || i == 0) {
    if (curPosInThisTurn >= 3584 && curPosInThisTurn <= 4096) {
      goalPosition = nextTurnPos;
    } else if (curPosInThisTurn >= 0 && curPosInThisTurn < 3584) {
      goalPosition = prevTurnPos;
    }
  }
  // if (i == 0) {
  //   goalPosition = prevTurnPos;
  // }
  if (i == 1 || i == 3) {
    if (curPosInThisTurn >= 512 && curPosInThisTurn <= 4096) {
      goalPosition = nextTurnPos;
    } else if (curPosInThisTurn >= 0 && curPosInThisTurn < 512) {
      goalPosition = prevTurnPos;
    } 
  }

  // if (abs(nextTurnPos - currentPos) < abs(currentPos - goalPosition)) {
  //   goalPosition = nextTurnPos;
  // }
  Serial.println();
  Serial.print(i);
  Serial.print(" current: ");
  Serial.print(curPosInThisTurn);
  Serial.print(" to prev: ");
  Serial.print (goalPosition - currentPos);
  Serial.print(" | to next: ");
  Serial.println(nextTurnPos - currentPos);

  goalPosition = goalPosition;
  motorStates[i].position = goalPosition;
}

void setMotorSteps(int i, double angle, int dir_flag) {
  // arbitrary step-to-angle conversion: A single turn takes the values 
  // from 0 to 4096 and in multiturn it can take -1,048,575 ~ 1,048,575
  // 11.38: 1 degree = 11.38 position; 30: each tooth is 30 degrees; 4: 4 motor packets 
  angle = angle * 11.38 * 30; 
  if (dir_flag == 1) {
    angle = -angle;
  }
  motorStates[i].position += angle;
}

void rxCharacteristicWritten(BLEDevice central, BLECharacteristic characteristic) {
  // central wrote new value to characteristic, update LED
  const uint8_t* msg = rxCharacteristic.value();
  bool all255 = true;
  for (int i = 0; i < 8; i++) {
    Serial.print(msg[i]);
    if (msg[i] != 255) { all255 = false; } 
  } 
  if (all255) { // if receiving reset command
    resetMotors();
  } else { // step or absolute commands
    for (int i = 0; i < DXL_ID_CNT; i++) {
      int dir_flag = msg[2*i];  // 1 for negative, 0 for positive
      double angle = msg[2*i+1];
      if (angle == 254) { // absolute condition
        returnToAbsolutePosition(i); // command the motor to return to abs position
      } else {
        setMotorSteps(i, angle, dir_flag);
      }
    }
  }

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
    }
  }  

  // Insert a new Goal Position to the SyncWrite Packet
  for (i = 0; i < DXL_ID_CNT; i++) {
    // sw_data[i].goal_position =  motorPositions[i];// this is the key
    sw_data[i].goal_position =  motorStates[i].position;// this is the key
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
  /////////////// END OF MOTOR CONTROL CODE ////////////////
}

