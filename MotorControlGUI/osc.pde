
// // Function to be called when speed button is pressed
// // Send speed command to Python
// public void Run() {
//   // osc send speed messages
//   // receives speed & the client address (corresponds to Python program 0, 1, etc.) the speed command should be sent to 
//   int speed = int(cp5.getController("speed").getValue());
//   OscMessage message = new OscMessage("/speed");  // create an OSC message with keyword
//   message.add(speed);  // attach the value
//   server.send(message, clientAddresses[page.activeMotorIndex]);  // sends OSC message
// }

// // Function to be called when brake button is pressed
// // Send brake command to python
// public void Brake() {
//   // osc send brake messages
//   // receives the client address (corresponds to Python program 0, 1, etc.) the speed command should be sent to 
//   OscMessage message = new OscMessage("/brake");  // create an OSC message with keyword
//   message.add(1); // You can replace 1 with any value you prefer for brake command
//   server.send(message, clientAddresses[page.activeMotorIndex]); // sends OSC message
// }

void osc_send_speed() {
  OscMessage message = new OscMessage("/motor");  // create an OSC message with keyword
  for (int i = 0; i < MAX_MOTORS; i++) {
    message.add(allMotorStatus[i]);
  }
  println(message);
  server.send(message, clientAddress);  // sends OSC message
}

void osc_send_reset() {
  OscMessage message = new OscMessage("/reset");  // create an OSC message with keyword
  println(message);
  server.send(message, clientAddress);  // sends OSC message
}

void oscEvent(OscMessage theOscMessage) {
  String addrPattern = theOscMessage.addrPattern();
  // Extract motor number from the address pattern
  int motorNumber = int(addrPattern.substring(4)); // Extract the number after "/imu"
  Motor motor = page.motors.get(motorNumber);

  // Assuming each motor sends 2 integers as per the bytes_to_ints() function in Python
  if (theOscMessage.checkTypetag("ii")) { // Check for two integers
    print(theOscMessage.get(0).intValue());
    print(theOscMessage.get(1).intValue());
    println("received osc imu from motor " + (motorNumber + 1));
  } 
  return;
}
