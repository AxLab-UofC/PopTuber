
class Command extends UIComponent {
  float duration;
  String label;

  Command(String label, float duration) {
    this.label = label;
    this.duration = duration;
    y = GAP_BTWEEN_TIMELINE_COMMANDS + y;
  }

  void drawSelf(){
    drawRect();
    drawLabel();
  }
  float getDuration() {
    return duration;
  }

  void setDuration(float duration) {
    this.duration = duration;
  }
  
  String getLabel() {
    return label;
  }

  float getWidth() {
    return timeManager.secondsToPixels(this.getDuration());
  }
  float getCenterX() {
    return getWidth() / 2 + x;
  }
  float getCenterY() {
    return y + COMMANDS_HEIGHT / 2;
  }
  void drawRect() {
    fill(this.getFillColor());
    strokeWeight(1);
    stroke(getGrey());
    float commandWidth = this.getWidth();
    rect(x, y, commandWidth, TOP_GAP - COMMANDS_HEIGHT);
  }

  void drawLabel() {
    fill(getBlack());
    textAlign(CENTER, CENTER);
    useBodyFont();
    float centerX = this.getCenterX();
    float centerY = this.getCenterY();
    float textWidth = textWidth("EXPAND");
    float commandWidth = this.getWidth();
    text(this.getLabel(), centerX, centerY);
    return;
  }
  color getFillColor() {
     if (label == "EXPAND") {
        return getExpandColor();
     }
     return getWhite();
  }
}

// enum CommandType { EXPAND, FEED, TILT }

// color getCommandDefaultColor(CommandType type) {
//   switch(type) {
//     case EXPAND:
//       return getYellow();
//     case FEED:
//       return getGreen();
//     case TILT:
//       return getBlue();
//     default:
//       return getBlue();
//   }
// }

Command loadCommandJSON(JSONObject json) {
  String name = json.getString("name");
  float duration = json.getFloat("duration");
  // command.setDuration(json.getFloat("duration"));

  Command command = createCommand(name,duration);
  return command;
}

Command createCommand(String type, float duration) {
  return new Command(type, duration);
}
