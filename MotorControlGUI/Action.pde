int initStepSize = 1;

final float SHORTEST_ACTION_LEN = 0.5;
final float ABSOLUTE_EXEC_TIME = 0.3;
final float TORQUE_PEAK_SEC = 0.1;
class Action extends UIComponent implements JSONAble {
  final ActionType type;
  float duration;
  float speed;
  Motor motor;
  Action(ActionType type, float duration, float speed) {
    this.type = type;
    this.duration = duration;
    this.speed = speed;
  }
  Action copy() {
    Action copy = new Action(this.type, this.duration, this.speed);
    return copy;
  }
  Motor getMotor() {
    return motor;
  }
  void setMotor(Motor motor) {
    this.motor = motor;
  }
  void drawSelf(){
    drawRect();
    drawLabel();
    drawStatus();
  }
  float getDuration() {
    return duration;
  }
  void setDuration(float duration) {
    this.duration = duration;
  }
  float getSpeed() {
    return speed;
  }
  void setSpeed(float speed) {
    this.speed = speed;
  }
  ActionType getType() {
    return type;
  }
  JSONObject toJSON() {
    JSONObject json = new JSONObject();
    json.setString("type", this.type.name());
    json.setFloat("duration", this.duration);
    json.setFloat("speed", this.speed);
    return json;
  }
  String toString() {
    return this.toJSON().toString();
  }
  String getLabel() {
    if (type == ActionType.SPEED) {
      return Float.toString(speed);
    } else if (type == ActionType.ABSOLUTE) {
      return "ABSOLUTE";
    }
    return type.name();
  }
  color getFillColor() {
     if (this.type == ActionType.ABSOLUTE) return getRed();
     if (this.speed == 0) return getWhite();
     if (this.speed > 0) return getCWColor();
     return getCCWColor();
  }
  float getWidth() {
    return timeManager.secondsToPixels(this.getDuration());
  }
  float getCenterX() {
    return getWidth() / 2 + x;
  }
  float getCenterY() {
    return y + ROW_HEIGHT / 2;
  }
  boolean isMouseOver() {
    if (mouseX > x 
      && mouseX < x + getWidth()
      && mouseY > y
      && mouseY < y + ROW_HEIGHT) return true;
    return false;
  }
  void drawRect() {
    fill(this.getFillColor());
    strokeWeight(1);
    stroke(getGrey());
    float actionWidth = this.getWidth();
    rect(x, y, actionWidth, ROW_HEIGHT);
    if (this.type == ActionType.ABSOLUTE && this.getDuration() > ABSOLUTE_EXEC_TIME) {
      float darkWidth = timeManager.secondsToPixels(ABSOLUTE_EXEC_TIME);
      strokeWeight(0);
      fill(getLightRed());
      rect(x + darkWidth, y, actionWidth - darkWidth, ROW_HEIGHT);
      strokeWeight(1);
    }
  }

  void drawLabel() {
    fill(getBlack());
    textAlign(CENTER, CENTER);
    useTitleFont();
    float centerX = this.getCenterX();
    float centerY = this.getCenterY();
    float textWidth = textWidth("ABSOLUTE");
    float actionWidth = this.getWidth();
    if (textWidth > actionWidth) {
      pushMatrix();
      translate(this.x + actionWidth / 2, this.y + ROW_HEIGHT / 2); // Center the rotation
      rotate(-HALF_PI); // Rotate 90 degrees
      text(this.getLabel(), 0, 0);
      popMatrix();
      return;
    }
    if (this.type == ActionType.ABSOLUTE) {
      text(this.getLabel(), centerX, centerY);
      return;
    }
    if (!motor.drawer.showRpm || speed == 0) {
      text("SPIN", centerX, centerY - 15);
      text(this.getLabel(), centerX, centerY + 15);
    } else {
      float rpm = page.rpmMapper.getRPM(motor.fw + "fw", abs(speed));
      text("SPIN", centerX, centerY - 25);
      text(this.getLabel(), centerX, centerY);
      text("RPM: " + str(speed > 0 ? rpm : -rpm), centerX, centerY + 25);
    }
  }

  void drawStatus() {
    float labelWidth = this.getWidth();
    String label = this.getLabel();
    float textWidth = textWidth(label);
    float centerX = this.getCenterX();
    float centerY = this.getCenterY();
    int actionIndex = this.motor.getActionIndex(this);
    Action lastAction = actionIndex == 0 ? null : this.motor.getAction(actionIndex - 1);
    RotationDirection torqueDirection = this.motor.getTorqueDirection(this, lastAction);
    if (!motor.drawer.showTorque) return;
    //imageMode(CENTER);
    //float iconX = x + timeManager.secondsToPixels(TORQUE_PEAK_SEC);
    //if (torqueDirection == RotationDirection.CW) {
    //  PImage icon = this.type == ActionType.ABSOLUTE ? cwBigTorqueIcon : cwTorqueIcon;
    //  image(icon, iconX, y + ROW_HEIGHT - ICON_SIZE);
    //} else if (torqueDirection == RotationDirection.CCW) {
    //  PImage icon = this.type == ActionType.ABSOLUTE ? ccwBigTorqueIcon : ccwTorqueIcon;
    //  image(icon, iconX, y + ICON_SIZE);
    //}
    //imageMode(CORNER);
  }
}

enum ActionType { SPEED, ABSOLUTE }

color getActionDefaultColor(ActionType type) {
  switch(type) {
    case SPEED:
      return getCWColor();
    case ABSOLUTE:
      return getRed();
    default:
      return getCWColor();
  }
}

Action loadActionJSON(JSONObject json) {
  ActionType type = ActionType.valueOf(json.getString("type"));
  Action action = createAction(type);
  action.setDuration(json.getFloat("duration"));
  action.setSpeed(json.getFloat("speed"));
  return action;
}

Action createAction(ActionType type) {
  switch(type) {
    case SPEED:
      return new Action(type, 1, initStepSize);
    case ABSOLUTE:
      return new Action(type, 1, 254);
    default:
      return null;
  }
}
