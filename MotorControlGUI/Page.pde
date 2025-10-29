List<Action> allProcessedActions = new ArrayList<Action>();   // all actions of all motors
int prevSize = 0;
float tempAngle = 0;

final float BOTTOM_RATIO = 0.3;
final float GAP_ROW_RATIO = 0.05;
final int BOTTOM_GAP = int(SCREEN_HEIGHT * BOTTOM_RATIO);
final int GAP_BTWEEN_TIMELINE_COMMANDS = 30;
final int COMMANDS_HEIGHT = 30;
final int TOP_GAP = GAP_BTWEEN_TIMELINE_COMMANDS + COMMANDS_HEIGHT;
final int ROW_HEIGHT = int((SCREEN_HEIGHT - BOTTOM_GAP - TOP_GAP) / (MAX_MOTORS + (MAX_MOTORS - 1) * GAP_ROW_RATIO));
final int ROW_GAP = int(ROW_HEIGHT * GAP_ROW_RATIO);

final int bodySize = 14;
final int titleSize = 18;

final int MOTOR_COL_WIDTH = int(ROW_HEIGHT * 1.2);
final int STATUS_COL_WIDTH = 0; //int(ROW_HEIGHT);
final int ACTION_START_X = MOTOR_COL_WIDTH + STATUS_COL_WIDTH;
final int BOTTOM_CENTER_Y = SCREEN_HEIGHT - BOTTOM_GAP / 2;
final int ICON_SIZE = 30;
final int LARGE_ICON_SIZE = 60;
final int SMALL_ICON_SIZE = 20;
final int USABLE_WIDTH = SCREEN_WIDTH - ACTION_START_X - 5;
final float BOX_WIDTH = ROW_HEIGHT * 0.5;
final float ICON_LABEL_MARGIN = 5;
final int SLIDER_WIDTH = ICON_SIZE / 3;
final int POPUP_WIDTH = 300;
final int POPUP_HEIGHT = 200;

final String FILE_NAME = "sequence.json"; // Change the file name and location as desired
final String TORQUE_JSON_NAME = "./data/unit_all_testonce.json";
final String RPM_JSON_NAME = "./data/rpm.json";

class Page extends UIComponent implements JSONAble {
  String name;
  final List<Motor> motors;             // List of all motors
  Action selectedAction;          // Currently selected action
  ActionController actionController; // Controller for the selected action

  final Button simulateButton;
  final Button playButton;              // Button to play/pause the sequence
  final Button resetButton;             // Button to reset the time
  final Button addMotorButton;
  final Button loadButton;
  final Button saveButton;
  final Button addExpandButton;
  final Button addFeedButton;
  final Button fold1;
  final Button fold2;
  final Button fold3;
  final Button fold4;  
  final Button fold5;
  final Button retract;
  final Button rotate;

  float x, y;

  TimeLine timeline;

  TorqueChartMapper torqueChartMapper;
  RPMMapper rpmMapper;

  PageState state;
  PageState defaultState;
  PageState realPlayState;
  PageState simulatePlayState;
  PageState realPauseState;
  PageState simulatePauseState;
  PageState individualMotorState;

  String popupText = null;
  int popupCountdown = 0;
  Motor selectedMotor = null;
  Motor copiedMotor = null;

  List<Command> commands;

  Page(String name) {
    this.name = name;

    this.actionController = new ActionController();
    this.timeline = new TimeLine();
    timeline.setXY(ACTION_START_X, 0);
    
    this.simulateButton = initSimulateButton();
    this.playButton = initPlayButton();
    this.resetButton = initResetButton();
    this.addMotorButton = initAddMotorButton();
    this.loadButton = initLoadButton();
    this.saveButton = initSaveButton();
    this.addExpandButton = initExpandButton();
    this.addFeedButton = initFeedButton();
    this.fold1 = initFold1();
    this.fold2 = initFold2();
    this.fold3 = initFold3();
    this.fold4 = initFold4();
    this.fold5 = initFold5();
    this.retract = initRetract();
    this.rotate = initRotate();

    motors = new ArrayList<Motor>();
    for (int i = 0; i < MAX_MOTORS; i++) {
      motors.add(new Motor(i));
    }

    this.torqueChartMapper = new TorqueChartMapper(loadJSONObject(TORQUE_JSON_NAME));
    this.rpmMapper = new RPMMapper(loadJSONObject(RPM_JSON_NAME));

    defaultState = new DefaultState(this);
    realPlayState = new RealPlayState(this);
    realPauseState = new RealPauseState(this);
    simulatePlayState = new SimulatePlayState(this);
    simulatePauseState = new SimulatePauseState(this);
    individualMotorState = new IndividualMotorState(this);
    state = defaultState;

    commands = new ArrayList<>();
  }

  void setState(PageState state) {
    this.state = state;
  }

  PageState getDefaultState() {
    return defaultState;
  }

  PageState getRealPlayState() {
    return realPlayState;
  }

  PageState getSimulatePlayState() {
    return simulatePlayState;
  }

  PageState getRealPauseState() {
    return realPauseState;
  }

  PageState getSimulatePauseState() {
    return simulatePauseState;
  }

  PageState getIndividualMotorState() {
    return individualMotorState;
  }
  
  Action getSelectedAction() {
    return selectedAction;
  }
  
  void setSelectedAction(Action action) {
    selectedAction = action;
  }

  Button initSimulateButton() {
    return initIconButton("simulatePlayButton", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("simulatePlayButton")) {
          page.state.clickSimulate();
        }
      }
    }, simulateIcon, LARGE_ICON_SIZE);
  }
  
  Button initPlayButton() {
    return initIconButton("playToggle", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("playToggle")) {
          page.state.clickPlay();
        }
      }
    }, playIcon, LARGE_ICON_SIZE);
  }

  Button initAddMotorButton() {
    return initIconButton("addMotor", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (!page.state.canModify()) return;
        if (event.getName().equals("addMotor")) {
          if (motors.size() < MAX_MOTORS) motors.add(new Motor(motors.size()));
        }
      }
    }, plusIcon, ICON_SIZE);
  }

  void loopPlayState() {
    for (Motor motor : motors) {
      motor.loopPlayState();
    }
  }

  void reset() {
    page.selectedAction = null;
    timeManager.resetTime();
    for (Motor motor : motors) {
      allMotorStatus[motor.getId()] = 0;
      motor.reset();
      commands.clear();
      print("after reset");
      print(allMotorStatus[motor.getId()]);
      print(" ");
    }
    this.commands.clear();
    osc_send_speed();
  }
  
  Button initResetButton() {
    return initIconButton("reset", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("reset")) {
          page.state.clickReset();
        }
      }
    }, resetIcon, LARGE_ICON_SIZE);
  }


  Button initFeedButton() {
    return initIconButton("feed", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("feed")) {
          // read feed json file and add to motor
          String filename = "3DFeed.json";
          try {
            appendLocalJSON(loadJSONObject(filename));
            println("Read sequence from " + filename);
            tempAngle += PI/6;
            println(tempAngle);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          }
        }
      }
    }, feedIcon, LARGE_ICON_SIZE);
  }

  Button initExpandButton() {
    return initIconButton("expand", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("expand")) {
          // read expand json file and add to motor
          String filename = "3DExpandLong.json";
          try {
            appendLocalJSON(loadJSONObject(filename));
            float duration = getTotalDurationFromJSON(loadJSONObject(filename));
            Command expandCommand = new Command("EXPAND", duration);
            commands.add(expandCommand);
            println("Read sequence from " + filename);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          }
        }
      }
    }, expandIcon, LARGE_ICON_SIZE);
  }

  Button initFold1() {
    return initIconButton("fold1", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        String filename = "3DFold1.json";
        if (event.getName().equals("fold1")) {
          try {
            page.appendLocalJSON(loadJSONObject(filename));
            println("Read sequence from " + filename);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          };
        }
      }
    }, fold1Icon, LARGE_ICON_SIZE);
  }

  Button initFold2() {
    return initIconButton("fold2", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        String filename = "3DFold2.json";
        if (event.getName().equals("fold2")) {
          try {
            page.appendLocalJSON(loadJSONObject(filename));
            println("Read sequence from " + filename);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          };
        }
      }
    }, fold2Icon, LARGE_ICON_SIZE);
  }

  Button initFold3() {
    return initIconButton("fold3", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        String filename = "3DFold3.json";
        if (event.getName().equals("fold3")) {
          try {
            page.appendLocalJSON(loadJSONObject(filename));
            println("Read sequence from " + filename);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          };
        }
      }
    }, fold3Icon, LARGE_ICON_SIZE);
  }

  Button initFold4() {
    return initIconButton("fold4", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        String filename = "3DFold4.json";
        if (event.getName().equals("fold4")) {
          try {
            page.appendLocalJSON(loadJSONObject(filename));
            println("Read sequence from " + filename);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          };
        }
      }
    }, fold4Icon, LARGE_ICON_SIZE);
  }

  Button initFold5() {
    return initIconButton("fold5", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        String filename = "3DFold5.json";
        if (event.getName().equals("fold5")) {
          try {
            page.appendLocalJSON(loadJSONObject(filename));
            println("Read sequence from " + filename);
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          };
        }
      }
    }, fold5Icon, LARGE_ICON_SIZE);
  }

  Button initRetract() {
    return initIconButton("retract", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("retract")) {
          page.state.clickReset();
          osc_send_reset();
          prevSize = 0;
          allProcessedActions.clear();
        }
      }
    }, retractIcon, LARGE_ICON_SIZE);
  }


  Button initRotate() {
    return initIconButton("rotate", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("rotate")) {
          try {
            page.appendLocalJSON(loadJSONObject("3DRotate.json"));
            println("Read sequence from " + "3DRotate.json");
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          };
        }
      }
    }, rotateIcon, LARGE_ICON_SIZE);
  }

  void drawControlButtons() {
    float iconY = BOTTOM_CENTER_Y - LARGE_ICON_SIZE / 2 - 70;
    float iconY2 = iconY + 100;
    float centerIconX = width/2 - LARGE_ICON_SIZE * 0.5;
    float leftGap = 350;
    float rightGap = 400;
    float foldButtonXGap = 70;
    float foldButtonXStart = centerIconX - LARGE_ICON_SIZE * 1.6;
    float labelY = iconY + LARGE_ICON_SIZE + ICON_LABEL_MARGIN;
    float labelY2 = labelY + 90;
    playButton.setPosition(centerIconX - leftGap, iconY);
    resetButton.setPosition(centerIconX - leftGap + 80, iconY);

    addExpandButton.setPosition(foldButtonXStart + foldButtonXGap, iconY);
    addFeedButton.setPosition(foldButtonXStart + 2*foldButtonXGap, iconY);

    retract.setPosition(centerIconX + 25 + rightGap, iconY);
    text("Reset", centerIconX + 35 + rightGap, labelY);
    rotate.setPosition(foldButtonXStart + 3*foldButtonXGap, iconY);
    text("Rotate", foldButtonXStart + 3*foldButtonXGap + 10, labelY);


    textAlign(CENTER, CENTER);

    text("Play/Pause", centerIconX - leftGap + 25, labelY);
    text("Back to Start", centerIconX - leftGap + 105, labelY);

    text("Expand", foldButtonXStart + foldButtonXGap+20, labelY);    
    text("Feed", foldButtonXStart + 2*foldButtonXGap + 20, labelY);  

    



    fold1.setPosition(foldButtonXStart, iconY2);
    fold2.setPosition(foldButtonXStart + foldButtonXGap, iconY2);
    fold3.setPosition(foldButtonXStart + 2*foldButtonXGap, iconY2);
    fold4.setPosition(foldButtonXStart + 3*foldButtonXGap, iconY2);
    fold5.setPosition(foldButtonXStart + 4*foldButtonXGap, iconY2);
    for (int i = 0; i < 5; i++) {
      text("Fold" + (i+1), foldButtonXStart + 20 + i*foldButtonXGap, labelY2);
    }

    saveButton.setPosition(width - ICON_SIZE * 1.5, BOTTOM_CENTER_Y - ICON_SIZE - 15);
    text("Save", width - ICON_SIZE * 1.5 + ICON_SIZE / 2, BOTTOM_CENTER_Y - 15 + ICON_LABEL_MARGIN);
    loadButton.setPosition(width - ICON_SIZE * 1.5, BOTTOM_CENTER_Y + 10);
    text("Load", width - ICON_SIZE * 1.5 + ICON_SIZE / 2, BOTTOM_CENTER_Y + ICON_SIZE + 10 + ICON_LABEL_MARGIN);
  }

  Button initSaveButton() {
    return initIconButton("SaveJSON", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("SaveJSON")) {
          try {
            saveJSONObject(page.toJSON(), FILE_NAME);
            println("Sequence saved to " + FILE_NAME);
          } catch (Exception e) {
            println("Error saving file: ");
            e.printStackTrace();
          }
        }
      }
    }, saveIcon, ICON_SIZE);
  }
  
  Button initLoadButton() {
    return initIconButton("LoadJSON", new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (event.getName().equals("LoadJSON")) {
          try {
            page.loadPageJSON(loadJSONObject(FILE_NAME));
            println("Sequence loaded from " + FILE_NAME);
            page.loadCommandJSON(loadJSONObject("_commands.json"));
            println("Command Blocks loaded");
          } catch (Exception e) {
            println("Error loading file: ");
            e.printStackTrace();
          }
        }
      }
    }, loadIcon, ICON_SIZE);
  }

  boolean hitIndividualMotor(int n) {
    if (n >= this.motors.size()) return false;
    selectedMotor = this.motors.get(n);
    if (selectedMotor.actions.size() > 0) {
      if (selectedMotor.playIndividual) {
        selectedMotor.reset();
        allMotorStatus[selectedMotor.getId()] = 0;
        osc_send_speed();
      } else {
        selectedMotor.playIndividual = true;
      }
      return true;
    }
    return false;
  }
  
  void drawHorizontalLines() {
    stroke(getBlack());
    strokeWeight(1);
    float y = TOP_GAP;
    for (int i = 0; i < MAX_MOTORS; i++) {
      line(0, y, width, y);
      y += ROW_HEIGHT;
      line(0, y, width, y);
      y += ROW_GAP;
    }
  }
  
  void drawVerticalLines() {
    stroke(getBlack());
    float y = TOP_GAP;
    
    for (int i = 0; i < MAX_MOTORS; i++) {
      line(MOTOR_COL_WIDTH, y, MOTOR_COL_WIDTH, y + ROW_HEIGHT);
      line(ACTION_START_X, y, ACTION_START_X, y + ROW_HEIGHT);
      y += ROW_GAP + ROW_HEIGHT;
    }
  }

  void setChildrenXY() {
    for (Motor motor : motors) {
      motor.setXY(0, motor.getId() * (ROW_HEIGHT + ROW_GAP) + TOP_GAP);
    }
  }
  void drawChildren() {
    motors.forEach(motor -> motor.draw());
  }

  void drawTitles() {
    //fill(getBlack());
    //useTitleFont();
    //textAlign(CENTER, CENTER);
    //text("Status", x + MOTOR_COL_WIDTH + STATUS_COL_WIDTH / 2,TOP_GAP / 2);
  }
  void drawMotorEditButtons() {
    addMotorButton.setPosition((MOTOR_COL_WIDTH - ICON_SIZE) / 2, TOP_GAP + motors.size() * (ROW_HEIGHT + ROW_GAP) + (ROW_HEIGHT - ICON_SIZE) / 2);
    if (motors.size() >= 4) {
      addMotorButton.hide();
    } else {
      addMotorButton.show();
    }
  }
  void drawInstructions() {
    float insX = 30;
    textAlign(LEFT, CENTER);
    useInsFont();
    fill(getBlack());
    if(loop){
      text("Loop on", insX, BOTTOM_CENTER_Y - 20);
    } else {
      text("Loop off", insX, BOTTOM_CENTER_Y - 20);
    }
    
    // text("Use arrow keys to reorder selected actions", insX, BOTTOM_CENTER_Y - 20);
    // text("Scroll on selected Speed Actions to change speed", insX, BOTTOM_CENTER_Y);
    // text("Drag the right side of selected action to change duration", insX, BOTTOM_CENTER_Y + 20);
    // text("Space to play/pause, R to reset, C to copy a motor's actions, V to paste", insX, BOTTOM_CENTER_Y + 40);
  }

  void drawPopup() {
    if (this.popupText == null) return;
    textAlign(CENTER, CENTER);
    useTitleFont();
    fill(getWhite());
    strokeWeight(3);
    rect((width - POPUP_WIDTH) / 2, (height - POPUP_HEIGHT) / 2, POPUP_WIDTH, POPUP_HEIGHT);
    fill(getBlack());
    strokeWeight(1);
    text(this.popupText, width / 2, height / 2);
    this.popupCountdown -= 1;
    if (this.popupCountdown <= 0) this.popupText = null;
  }

  void drawCommands() {
    float lastEndX = MOTOR_COL_WIDTH + STATUS_COL_WIDTH;
    for (Command c : commands) {
      c.x = lastEndX;
      lastEndX += timeManager.secondsToPixels(c.duration);
      c.draw();
    }
  }

  void drawSelf() {
    drawTitles();
    drawMotorEditButtons();

    timeline.draw();
    actionController.draw();
    drawInstructions();
    drawHorizontalLines();
    drawVerticalLines();
    drawControlButtons();

    drawPopup();
    drawCommands();
    // drawSimulation();
  }

  void drawSimulation() {
    int d = 100;
    int gap = 100;
    int x = width/2;
    int y = SCREEN_HEIGHT - d/2 - gap;
    drawMotorSims(0, x, y, d);
    drawMotorSims(1, x, y, d);
    drawMotorSims(2, x, y, d);
    drawMotorSims(3, x, y, d);
  }

  void drawMotorSims(int id, int x, int y, int d) {
    int dist = d + 10;
    int labelCircleGap = d/2 + 10;
    int labelX = x - labelCircleGap; 
    int labelY = y;
    if (id == 1) {
      x = x + dist;
      labelX = x + labelCircleGap; 
    } else if (id == 2) {
      y = y - dist;
      labelX = x - labelCircleGap; 
      labelY -= d;
    } else if (id == 3) {
      x = x + dist;
      y = y - dist;
      labelX = x + labelCircleGap; 
      labelY -= d;
    }
    textAlign(CENTER, CENTER);
    text(id + 1, labelX, labelY);
    strokeWeight(3);
    circle(x,y,d); // motor
    circle(x,y,5); // motor center
    drawTeeth(id,x,y,d);
  }

  void drawTeeth(int id, int x, int y, int d) {
    //oneRound = 4096;
    //oneDegree = sensorData / 
    //float stepAngle = 0;
    
  }

  void execute() {
    for (Motor motor : motors) {
      motor.updateActions();
    }
    // add all actions of all motors into a master action list
    // if the list size grows by 4, send speed.
    if (allProcessedActions.size() - prevSize == MAX_MOTORS) {
      osc_send_speed();
      print("prev = ");
      print(prevSize);
      prevSize = allProcessedActions.size();
      print("\t sent, current size = ");
      println(allProcessedActions.size());
    }
  }

  void executeIndividually() {
    for (Motor motor : motors) {
      if (motor.playIndividual) motor.updateActions();
    }
  }

  void simulate() {
   for (Motor motor : motors) {
      motor.simulate();
    } 
  }
  
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("name", name);
    JSONArray motorsJSON = new JSONArray();
    for (int i = 0; i < motors.size(); i++) {
      motorsJSON.setJSONObject(i, motors.get(i).toJSON());
    }
    json.setJSONArray("motors", motorsJSON);
    return json;
  }

  Motor loadMotorJSON(JSONObject json, int id) {
    Motor motor = new Motor(id);
    JSONArray actionsJSON = json.getJSONArray("actions");
    for (int i = 0; i < actionsJSON.size(); i++) {
      JSONObject actionJSON = actionsJSON.getJSONObject(i);
      motor.insertAction(loadActionJSON(actionJSON), i);
    }
    return motor;
  }
  
  String toString() {
    JSONObject json = toJSON();
    return toJSON().toString();
  }

  void loadPageJSON(JSONObject json) {
    this.reset();
    for (Motor motor : this.motors) {
      motor.drawer.clear();
    }
    this.motors.clear();
    JSONArray motorsJSON = json.getJSONArray("motors");
    for (int i = 0; i < motorsJSON.size(); i++) {
      JSONObject motorJSON = motorsJSON.getJSONObject(i);
      this.motors.add(this.loadMotorJSON(motorJSON, i));
    }
  }

void loadCommandJSON(JSONObject json) {
  // Get the JSON array named "commands"
  JSONArray commandsArray = json.getJSONArray("commands");
  
  // Iterate through each command in the array
  for (int i = 0; i < commandsArray.size(); i++) {
    // Get the current command object
    JSONObject command = commandsArray.getJSONObject(i);
    
    String name = command.getString("name");
    float duration = command.getFloat("duration"); // Use getFloat for floating-point numbers
    Command newCommand = createCommand(name, duration);
    commands.add(newCommand);
  }
}

  void appendLocalJSON(JSONObject json) {
    JSONArray motorsJSON = json.getJSONArray("motors");
    for (int i = 0; i < motorsJSON.size(); i++) {
      JSONObject motorJSON = motorsJSON.getJSONObject(i);
      JSONArray actionsJSON = motorJSON.getJSONArray("actions");
      for (int j = 0; j < actionsJSON.size(); j++) {
        JSONObject actionJSON = actionsJSON.getJSONObject(j);
        motors.get(i).insertAction(loadActionJSON(actionJSON), motors.get(i).getActions().size());
      }
    }
  }

  float  getTotalDurationFromJSON(JSONObject json) {
    float  duration = 0;
    JSONArray motorsJSON = json.getJSONArray("motors");
    JSONObject motorJSON = motorsJSON.getJSONObject(0);
    JSONArray actionsJSON = motorJSON.getJSONArray("actions");
    for (int j = 0; j < actionsJSON.size(); j++) {
      JSONObject actionJSON = actionsJSON.getJSONObject(j);
      duration += loadActionJSON(actionJSON).getDuration();
    }
    return duration;
  }

  // void drawCommandLabel(String label, float  duration) {
  //   text(label, 100, 100);
  //   text("" + duration, 150, 100);
  // }
}
