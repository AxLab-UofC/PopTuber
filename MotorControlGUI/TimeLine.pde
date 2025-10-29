// singleton
final TimeLine timeline = new TimeLine();
final int MIN_SECONDS = 6;
class TimeLine extends UIComponent {
  TimeLine() {}
  void drawSelf() {
    int numTicks = max(ceil(timeManager.getTotalSeconds()) + 1, MIN_SECONDS) + 1;
    int tickSpacing = USABLE_WIDTH / (numTicks - 1);
    drawTicks(numTicks, tickSpacing, x, y);
    drawScanningTimePos();
  }
  
  // Method to draw the current position (red line) along the timeline
  void drawScanningTimePos() {
    // TODO: refactor this to be state driven
    boolean individual = false;
    for (Motor m :page.motors) {
      if (m.playIndividual || m.individualSeconds > 0) {
        individual = true;
        break;
      }
    }
    if (individual) {
      drawIndividualTimePos();
    } else {
      drawGlobalTimePos();
    }
  }

  void drawIndividualTimePos(){
    stroke(getBlack());
    strokeWeight(3);
    for (int i = 0; i < page.motors.size(); i++) {
      Motor m = page.motors.get(i);
      if (!(m.playIndividual || m.individualSeconds > 0)) {
        continue;
      }
      float travelled = timeManager.secondsToPixels(m.individualSeconds);
      float lineX = travelled + MOTOR_COL_WIDTH + STATUS_COL_WIDTH;
      float y = m.y;
      line(lineX, y, lineX, y + ROW_HEIGHT);
    }
    strokeWeight(1);
  }
  void drawGlobalTimePos(){
    float travelled = timeManager.secondsToPixels(timeManager.getCurrSeconds());
    float lineX = travelled + MOTOR_COL_WIDTH + STATUS_COL_WIDTH;
    stroke(getBlack());
    strokeWeight(3);
    float y = TOP_GAP;
    line(lineX, y, lineX, y + ROW_HEIGHT * MAX_MOTORS + ROW_GAP * (MAX_MOTORS - 1));
    strokeWeight(1);
  }

  void drawTicks(int num, float spacing, float x, float y) {
    useInsFont();
    textAlign(CENTER, CENTER);
    stroke(getBlack());
    strokeWeight(1);
    for (int i = 0; i < num; i++) {
      line(x, y, x, y + 10);
      text(i, x, 20);
      x += spacing;
    }
  }
}
