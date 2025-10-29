void motorSetup() {
  uint8_t i;
  // Fill the members of structure to syncRead using external user packet buffer
  sr_infos.packet.p_buf = user_pkt_buf;
  sr_infos.packet.buf_capacity = user_pkt_buf_cap;
  sr_infos.packet.is_completed = false;
  sr_infos.addr = SR_START_ADDR;
  sr_infos.addr_length = SR_ADDR_LEN;
  sr_infos.p_xels = info_xels_sr;
  sr_infos.xel_count = 0;

  // Prepare the SyncRead structure
  for(i = 0; i < DXL_ID_CNT; i++) {
    info_xels_sr[i].id = DXL_ID_LIST[i];
    info_xels_sr[i].p_recv_buf = (uint8_t*)&sr_data[i];
    sr_infos.xel_count++;
  }
  sr_infos.is_info_changed = true;

  // Fill the members of structure to syncWrite using internal packet buffer
  sw_infos.packet.p_buf = nullptr;
  sw_infos.packet.is_completed = false;
  sw_infos.addr = SW_START_ADDR;
  sw_infos.addr_length = SW_ADDR_LEN;
  sw_infos.p_xels = info_xels_sw;
  sw_infos.xel_count = 0;

  for(i = 0; i < DXL_ID_CNT; i++) {
    info_xels_sw[i].id = DXL_ID_LIST[i];
    info_xels_sw[i].p_data = (uint8_t*)&sw_data[i].goal_position;
    sw_infos.xel_count++;
  }
  sw_infos.is_info_changed = true;
}

void initMotors() {
  // Turn off torque when configuring items in EEPROM area
  for (int i = 0; i < DXL_ID_CNT; i++) {
    Motor &motor = motorStates[i];
    dxl.ping(motor.id); // Get DYNAMIXEL information
    dxl.torqueOff(motor.id);
    dxl.setOperatingMode(motor.id, OP_EXTENDED_POSITION);
    dxl.torqueOn(motor.id);
    // dxl.setGoalPosition(motor.id, 0, UNIT_DEGREE);
    motor.position = 0;
    returnToAbsolutePosition(i);
    // dxl.setGoalPosition(motor.id, 0, UNIT_DEGREE);
  }
  resetMotors();

  dxl.torqueOn(BROADCAST_ID);
}

void resetMotors() {
  // Turn off torque when configuring items in EEPROM area
  for (int i = 0; i < DXL_ID_CNT; i++) {
    Motor &motor = motorStates[i];
    motor.position = 0;
    dxl.setGoalPosition(motor.id, 0, UNIT_DEGREE);
  }
  for (int i = 0; i < DXL_ID_CNT; i++) {
    Motor &motor = motorStates[i];
    returnToAbsolutePosition(i);
    dxl.setGoalPosition(motor.id, motor.position, UNIT_DEGREE);
  }
}