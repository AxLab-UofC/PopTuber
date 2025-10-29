class RPMDrawer extends UIComponent {
  final Motor motor;
  RPMDrawer(Motor motor) {
    this.motor = motor;
  }

  void drawYTicks(float x, float y, float maxVal, float maxRange) {
    textAlign(RIGHT, CENTER);
    useTicksFont();
    strokeWeight(0.5);
    fill(getRPMYAxisColor());
    stroke(getRPMYAxisColor());
    float tickLen = -4;
    float textGap = -8;
    text(str(0), x + textGap, y);
    line(x, y, x + tickLen, y);
    float zeroY = y;

    int spaces = LINE_CHART_NUM_TICKS - 1;
    float spacing = map(1, 0, spaces, 0, LINE_CHART_VERTICAL_RANGE / 2);
    float gap = spacing;
    float MAX_RPM = page.rpmMapper.getMaxRPM(motor.fw + "fw");
    for (int i = 1; i < LINE_CHART_NUM_TICKS; i++) {
      String numStr = str(round(-i * MAX_RPM / spaces));
      line(x, y + gap, x + tickLen, y + gap);
      text(numStr, x + textGap, y + gap);

      numStr = str(round(i * MAX_RPM / spaces));
      line(x, y - gap, x + tickLen, y - gap);
      text(numStr, x + textGap, y - gap);
      gap += spacing;
    }
    strokeWeight(1);
    textAlign(CENTER, CENTER);
  }

  void drawSelf() {
    if (!motor.drawer.showRpm) return;
    int MAX_RPM = round(page.rpmMapper.getMaxRPM(motor.fw + "fw"));
    drawYTicks(width, y, MAX_RPM, LINE_CHART_VERTICAL_RANGE);
    strokeWeight(1.5);
    List<Action> actions = motor.actions;
    float lineStartX = x;
    for (int i = 0; i < actions.size(); i++) {
      Action currAction = actions.get(i);
      ActionType currType = currAction.getType();
      float speed = currAction.getSpeed();
      float duration = currAction.getDuration();
      int rpm = page.rpmMapper.getRPM(motor.fw + "fw", abs(speed));
      if (rpm != 0) {
        rpm = speed > 0 ? rpm : -rpm;
        float lineY = map(rpm, -MAX_RPM, MAX_RPM, y - LINE_CHART_VERTICAL_RANGE / 2, y + LINE_CHART_VERTICAL_RANGE / 2);
        line(lineStartX, lineY, lineStartX + timeManager.secondsToPixels(duration), lineY);
      }
      lineStartX += timeManager.secondsToPixels(duration);
    }
  }
}
