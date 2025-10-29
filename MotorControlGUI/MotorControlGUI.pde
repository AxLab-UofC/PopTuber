// Import necessary libraries
import controlP5.*;
import java.util.*;
import java.io.*;
import java.time.*;
import oscP5.*;
import netP5.*;
import processing.core.*;
import processing.data.*;  // add this line if Cannot find a class or type named 'JSONObject'
import processing.event.*;  // add this line if Cannot find a class or type named 'mouseEvent'
//  add 'public' modifier to the return type if Cannot find a class or type named 'Overridepublic'


// OSC
final int MAX_MOTORS = 5;

//final int SCREEN_WIDTH = 1800;
//final int SCREEN_HEIGHT = 900;

 //temp for cv demo
final int SCREEN_WIDTH = 1500;
final int SCREEN_HEIGHT = 850;

final int FPS = 60;

int OSC_PORT_IN = 5004; // declare 1 port in for receiving OSC messages. Messages will be differentiated by keywords
int OSC_PORT_OUT = 5005;
// declare 2+ ports out for sending messages to Python programs
// in Python program 0, create an osc server that listens on 5005. In Python program 1, create an osc server that listens on 5006.

OscP5 server;  // declare osc server
NetAddress clientAddress;  // declare osc client addresses

// Each motor object in Processing corresponds to a unique client address, Python program, and Seeed board.
// Go to osc.pde for more OSC functions
// Go to addSpeedModule & addBrakeModule for OSC function calls

// UI controls and page objects
ControlP5 cp5;

Page page;
TimeManager timeManager;
void settings() {
  size(SCREEN_WIDTH, SCREEN_HEIGHT);
}

void setup() {
  cp5 = new ControlP5(this);
  
  // Canvas configuration
  noStroke();
  background(220);
  
  // Initialize UI components
  loadIcons();
  loadMyFont();
  page = new Page("Untitled");
  timeManager = new TimeManager();
  
  // initialize OSC server & client addresses based on declared ports
  server = new OscP5(this, OSC_PORT_IN);
  clientAddress = new NetAddress("127.0.0.1", OSC_PORT_OUT);
  
  frameRate(FPS);
}

void draw() {
  try {
    background(getWhite());
    page.draw();
    timeManager.updateTime();
  } catch(Exception err) {
    err.printStackTrace();
    exit();
  }
}

void mousePressed() {
  if (!page.state.canModify()) return;
  Action clickedAction = findClickedAction();
  if (clickedAction != null) {
    page.selectedAction = clickedAction;
  } else {
    page.selectedAction = null;
  }
  
  DurationSlider durationSlider = page.actionController.durationSlider;
  if (durationSlider.isMouseOver()) {
    durationSlider.locked = true;
    durationSlider.xOffset = mouseX;
  }
}

void mouseDragged() {
  sliderDragHandler();
}

void mouseReleased() {
  sliderReleaseHandler();
  Motor clickedMotor = findClickedMotor();
  if (clickedMotor == null) {
    page.selectedMotor = null;
    return;
  }
  page.selectedMotor = clickedMotor;
}

void mouseMoved() {
  if (cp5.getMouseOverList().size() > 0) {
    cursor(HAND);
    return;
  }
  if (page.selectedAction != null && page.state.canModify() && page.actionController.durationSlider.isMouseOver()) {
    cursor(HAND);
    return;
  }
  cursor(ARROW);
}

void mouseWheel(MouseEvent event) {
  actionScrollHandler(event.getCount());
}

void keyPressed() {
  Action selectedAction = page.selectedAction;
  if (selectedAction != null && key == CODED &&
    (keyCode == LEFT || keyCode == RIGHT)
  ) {
      shiftAction(selectedAction);
  }
  if (selectedAction != null && key == CODED &&
    (keyCode == UP || keyCode == DOWN)
  ) {
      speedChangeHandler();
  }
  if (key == ' ') {
    page.state.hitSpace();
  }
  if (key == 'r') {
    page.state.clickReset();
  }
  
  if (key == 'o') {
    page.state.clickReset();
    osc_send_reset();
    prevSize = 0;
    allProcessedActions.clear();
  }

  // key c used to be copy
  // if (key == 'c' && page.selectedMotor != null && page.selectedMotor.actions.size() > 0) {
  //   page.copiedMotor = page.selectedMotor;
  //   page.popupText = "Copied Motor " + page.copiedMotor.id + "!";
  //   page.popupCountdown = 60 * 2;
  // }
  if (key == 'l') {
    loop = !loop;
  }

  if (key == 'c') {
    try {
      page.appendLocalJSON(loadJSONObject("collapse.json"));
      println("Read sequence from " + "collapse.json");
    } catch (Exception e) {
      println("Error loading file: ");
      e.printStackTrace();
    };
  }
  if (key == 'v' && page.state.canModify() && page.selectedMotor != null && page.copiedMotor != null) {
    if (page.selectedMotor == page.copiedMotor) return;
    if (!page.selectedMotor.actions.isEmpty()) {
      page.selectedMotor.actions.clear();
      allMotorStatus[page.selectedMotor.getId()] = 0;
       osc_send_speed();
    }
    for (Action action : page.copiedMotor.actions) {
      page.selectedMotor.insertAction(action.copy(), page.selectedMotor.actions.size());
    }
  }

  // if (key >= '1' && key <= '9') {
  //   int pressed = key - '0';
  //   String filename = "3DFold" + pressed + ".json";
  //   try {
  //     page.appendLocalJSON(loadJSONObject(filename));
  //     println("Read sequence from " + filename);
  //   } catch (Exception e) {
  //     println("Error loading file: ");
  //     e.printStackTrace();
  //   };
  // } 

  if (key >= '1' && key <= '9') {
    int pressed = key - '0';
    String filename = "3DFeed" + pressed + ".json";
    try {
      page.appendLocalJSON(loadJSONObject(filename));
      println("Read sequence from " + filename);
    } catch (Exception e) {
      println("Error loading file: ");
      e.printStackTrace();
    };
  }

  if (key == '0') {
    for (Motor motor : page.motors) {
      motor.actions.clear();
    }
  }  

  if (key == 'a') { // all actions after the clicked one will be cleared
    int index = page.selectedMotor.getActionIndex(page.selectedAction);
    print("index");
    println(index);
    for (Motor motor : page.motors) {
      while (motor.actions.size() > index) {
        motor.actions.remove(index);
      }
    }
  }

  if (key == 't') { // all actions after the clicked one will be cleared
    try {
      page.appendLocalJSON(loadJSONObject("3DRotate.json"));
      println("Read sequence from " + "3DRotate.json");
    } catch (Exception e) {
      println("Error loading file: ");
      e.printStackTrace();
    };
  }

  if (key == 'e') { // all actions after the clicked one will be cleared
    try {
      page.appendLocalJSON(loadJSONObject("3DExpandShort.json"));
      println("Read sequence from " + "3DExpandShort.json");
    } catch (Exception e) {
      println("Error loading file: ");
      e.printStackTrace();
    };
  }

  if (key == 'x') { // all actions after the clicked one will be cleared
    try {
      page.appendLocalJSON(loadJSONObject("retractexpand.json"));
      println("Read sequence from " + "retractexpand.json");
    } catch (Exception e) {
      println("Error loading file: ");
      e.printStackTrace();
    };
  }

}
