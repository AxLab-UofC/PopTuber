void setupBLE() {
  // begin initialization
  if (!BLE.begin()) {
    Serial.println("starting Bluetooth® Low Energy module failed!");
    while(1);
  }
  Serial.println("BLE beginned");

  // set advertised local name and service UUID:
  BLE.setLocalName("Arduino MKR 1010");
  BLE.setDeviceName("Arduino MKR 1010");
  BLE.setAdvertisedService(bleService);

  // add the characteristic to the service
  bleService.addCharacteristic(rxCharacteristic);
  // add service
  BLE.addService(bleService);

  // assign event handlers for connected, disconnected to peripheral
  BLE.setEventHandler(BLEConnected, blePeripheralConnectHandler);
  BLE.setEventHandler(BLEDisconnected, blePeripheralDisconnectHandler);

  // set the initial value for the characeristic:
  // rxCharacteristic.setEventHandler(BLEWritten, rxCharacteristicWritten);
  rxCharacteristic.setValue(0);
  rxCharacteristic.setEventHandler(BLEWritten, rxCharacteristicWritten);


  // start advertising
  BLE.advertise();

  Serial.println("BLE LED Peripheral advertising...");  
}