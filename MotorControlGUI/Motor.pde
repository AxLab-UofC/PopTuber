// global list that keeps track of all motor current status
float[] allMotorStatus = new float[MAX_MOTORS];

enum RotationDirection {
  IDLE,
  CW,
  CCW
}
class Motor extends UIComponent implements JSONAble {
  final List<Action> actions = new ArrayList<Action>();   // List of actions assigned to the motor
  final MotorDrawer drawer;
  final MotorStatusDrawer motorStatusDrawer;
  final TorqueChartDrawer torqueChartDrawer;
  final RPMDrawer rpmDrawer;
  MotorIMU imu;
  final int id;
  RotationDirection motorDirection;
  RotationDirection torqueDirection;
  boolean bigTorque = false;
  int fw = 0;
  float individualSeconds = 0;
  boolean playIndividual = false;
  Set<Action> processed = new HashSet<Action>();

  Motor(int id) {
    this.imu = new MotorIMU();
    this.id = id;
    this.drawer = new MotorDrawer(this);
    this.motorStatusDrawer = new MotorStatusDrawer(this);
    this.motorDirection = RotationDirection.IDLE;
    this.torqueChartDrawer = new TorqueChartDrawer(this);
    this.rpmDrawer = new RPMDrawer(this);
  }
  
  int getId() { return id; }
  
  // Calculate the total duration of all actions
  float getSequenceLength() {
    float total = 0;
    for (Action action : actions) {
      total += action.getDuration();
    }
    return total;
  }
  void drawSelf() {
    drawer.draw(this.x, this.y);
    // motorStatusDrawer.setXY(MOTOR_COL_WIDTH + this.x, this.y).draw();
    torqueChartDrawer.setXY(ACTION_START_X, this.y + ROW_HEIGHT / 2).draw();
    // rpmDrawer.setXY(ACTION_START_X, this.y + ROW_HEIGHT / 2).draw();
  }
  void setChildrenXY() {
    float lastEndX = MOTOR_COL_WIDTH + STATUS_COL_WIDTH;
    for (Action action : this.getActions()) {
      action.setXY(lastEndX, this.y);
      lastEndX += timeManager.secondsToPixels(action.getDuration());
    }
  }
  void drawChildren() {
    actions.forEach(action -> action.draw());
  }

  void loopPlayState() {
    processed.clear();
  }
  
  void reset() {
    loopPlayState();
    this.motorDirection = RotationDirection.IDLE;
    this.torqueDirection = RotationDirection.IDLE;
    this.bigTorque = false;
    this.individualSeconds = 0;
    this.playIndividual = false;
  }

  RotationDirection getMotorDirection(float speed) {
    return speed > 0 ? RotationDirection.CW : speed < 0 ? RotationDirection.CCW : RotationDirection.IDLE;
  }

  RotationDirection getTorqueDirection(Action currAction, Action lastAction) {
    float diff = lastAction == null ? currAction.speed : currAction.speed - lastAction.speed;
    return diff > 0 ? RotationDirection.CCW : diff < 0 ? RotationDirection.CW : RotationDirection.IDLE;
  }
  

  void updateActions() {
    float currTime = playIndividual ? individualSeconds : timeManager.getCurrSeconds();
    float pastTime = 0;
    for (int i = 0; i < actions.size(); i++) {
      Action action = getAction(i);
      if (pastTime > currTime) { 
        return;
      }
      if (!processed.contains(action)) {
        processed.add(action);
        allProcessedActions.add(action);
        float speed = action.getSpeed();
        if (action.type == ActionType.SPEED) {
          this.bigTorque = false;
          allMotorStatus[id] = speed;
          
        } else if (action.type == ActionType.ABSOLUTE) {
          this.bigTorque = true;
          allMotorStatus[id] = 0;
          allMotorStatus[id] = 254; // arbitrary flag
        }
        this.motorDirection = getMotorDirection(speed);
        this.torqueDirection = getTorqueDirection(action, i == 0 ? null : getAction(i - 1));
        return;
      }
      pastTime += action.getDuration();
    }
  }

  void simulate() {
    float currTime = timeManager.getCurrSeconds();
    float pastTime = 0;
    for (int i = 0; i < actions.size(); i++) {
      Action action = getAction(i);
      if (pastTime > currTime) {
        return;
      }
      if (!processed.contains(action)) {
        processed.add(action);
        allProcessedActions.add(action);
        float speed = action.getSpeed();
        if (action.type == ActionType.SPEED) {
          this.bigTorque = false;
        } else if (action.type == ActionType.ABSOLUTE) {
          this.bigTorque = true;
        }
        this.motorDirection = getMotorDirection(speed);
        this.torqueDirection = getTorqueDirection(action, i == 0 ? null : getAction(i - 1));
        return;
      }
      pastTime += action.getDuration();
    }
  }
  
  List<Action> getActions() { return actions; }
  
  void insertAction(Action action, int index) {
    action.setMotor(this);
    actions.add(index, action);
  }

  int getActionIndex(Action action) {
    return actions.indexOf(action);
  }

  Action getAction(int index) {
    return actions.get(index);
  }
  
  Action removeAction(Action action) {
    action.setMotor(null);
    actions.remove(getActionIndex(action));
    return action;
  }


  float getActionStartTime(Action action) {
    float startTime = 0;
    for (Action curr : getActions()) {
      if (curr == action) break;
      startTime += curr.getDuration();
    }
    return startTime;
  }
  
  int findIndexToInsert(float startTime) {
    // after the first one that ends after startTime
    float currTime = 0;
    for (int i = 0; i < actions.size(); i++) {
      if (currTime + getAction(i).getDuration() >= startTime) {
        return i + 1;
      }
      currTime += getAction(i).getDuration();
    }
    return actions.size();
  }
  
  String toString() {
    return toJSON().toString();
  }
  
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("address", clientAddress.toString());
    JSONArray actionsJSON = new JSONArray();
    for (int i = 0; i < actions.size(); i++) {
      actionsJSON.setJSONObject(i, getAction(i).toJSON());
    }
    json.setJSONArray("actions", actionsJSON);
    return json;
  }
}

Motor findClickedMotor() {
  for (Motor motor : page.motors) {
    if (motor.drawer.isMouseOver()) {
      return motor;
    }
  }
  return null;
}
