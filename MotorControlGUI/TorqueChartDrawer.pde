final float LINE_CHART_VERTICAL_RANGE = ROW_HEIGHT * 0.9;
final float BUFFER_TIME = 0.05; // for clarity when drawing the initial part of curves
final int SMOOTH_DEGREE = 7;
final int LINE_CHART_NUM_TICKS = 3; // on one direction of the y axis
class TorqueChartDrawer extends UIComponent {
  final Motor motor;
  TorqueChartDrawer(Motor motor) {
    this.motor = motor;
  }
  
  void drawFlatLine(float x, float y, float duration) {
    stroke(getTorqueYAxisColor());
    strokeWeight(2);
    line(x, y, x + timeManager.secondsToPixels(duration), y);
  }
  // make a float[][] smoother. Useful for curves
  float[][] smoothTimeToTorque(float[][] original) {
    float[][] smoothed = new float[original.length * (SMOOTH_DEGREE + 1)][2];
    // insert transition points into the original array before every timestamp
    for (int i = 0; i < original.length; i++) {
      float timestamp = original[i][0];
      float torque = original[i][1];
      int intervals = SMOOTH_DEGREE + 1;
      smoothed[SMOOTH_DEGREE + i * (SMOOTH_DEGREE + 1)] = original[i];
      float lastTimestamp = i == 0 ? 0 : original[i - 1][0];
      float lastTorque = i == 0 ? 0 : original[i - 1][1];
      for (int j = 0; j < SMOOTH_DEGREE; j++) {
        smoothed[i * intervals + j][0] = timestamp - (timestamp - lastTimestamp) * (SMOOTH_DEGREE - j) / intervals;
        smoothed[i * intervals + j][1] = torque - (torque - lastTorque) * (SMOOTH_DEGREE - j) / intervals;
      }
    }
    return smoothed;
  }
  
  void plot(float x, float y, float duration, float[][] timeToTorque, boolean flip) {
    if (timeToTorque == null) {
      drawFlatLine(x, y, duration);
      return;
    }
    float currTime = 0;
    noFill();
    stroke(getTorqueYAxisColor());
    strokeWeight(2);
    drawFlatLine(x, y, BUFFER_TIME);
    // // the curve approach. Looks nice but curve can disconnect
    // beginShape();
    // curveVertex(x, y);
    // if (SMOOTH_DEGREE > 0) {
    //   timeToTorque = smoothTimeToTorque(timeToTorque); // drastic changes break curves
    // }
    // for (int i = 0; i < timeToTorque.length; i++) {
    //   float[] timeTorquePair = timeToTorque[i];
    //   float timestamp = timeTorquePair[0] + BUFFER_TIME;
    //   float torque = timeTorquePair[1] * (flip ? - 1 : 1); // flip since json only has positive
    //   if (timestamp > duration) break;
    //   if (timestamp > currTime) {
    //     curveVertex(x + timeManager.secondsToPixels(timestamp), map(torque, -MAX_TORQUE, MAX_TORQUE, y - LINE_CHART_VERTICAL_RANGE / 2, y + LINE_CHART_VERTICAL_RANGE / 2));
    //   }
    //   currTime = timestamp;
    // }
    // endShape();

    // // the straight line approach. Looks weird but always connected
    float lastX = x + timeManager.secondsToPixels(BUFFER_TIME);
    float lastY = y;
    float MAX_TORQUE = page.torqueChartMapper.getMaxTorque(motor.fw + "fw");
    for (int i = 0; i < timeToTorque.length; i++) {
      float[] timeTorquePair = timeToTorque[i];
      float timestamp = timeTorquePair[0] + BUFFER_TIME;
      float torque = timeTorquePair[1] * (flip ? - 1 : 1); // flip since json only has positive
      if (timestamp > duration) break;
      if (timestamp > currTime) {
        float nextX = x + timeManager.secondsToPixels(timestamp);
        float nextY = map(torque, -MAX_TORQUE, MAX_TORQUE, y - LINE_CHART_VERTICAL_RANGE / 2, y + LINE_CHART_VERTICAL_RANGE / 2);
        line(lastX, lastY, nextX, nextY);
        lastX = nextX;
        lastY = nextY;
      }
      currTime = timestamp;
    }
    if (currTime < duration) drawFlatLine(x + timeManager.secondsToPixels(currTime), y, duration - currTime);
  }

  void drawYTicks(float x, float y, float maxVal, float maxRange) {
    textAlign(LEFT, CENTER);
    useTicksFont();
    strokeWeight(0.5);
    fill(getTorqueYAxisColor());
    stroke(getTorqueYAxisColor());
    float tickLen = 4;
    float textGap = 8;
    text(str(0), x + textGap, y);
    line(x, y, x + tickLen, y);
    float zeroY = y;

    int spaces = LINE_CHART_NUM_TICKS - 1;
    float spacing = map(1, 0, spaces, 0, LINE_CHART_VERTICAL_RANGE / 2);
    float gap = spacing;
    float MAX_TORQUE = page.torqueChartMapper.getMaxTorque(motor.fw + "fw");
    for (int i = 1; i < LINE_CHART_NUM_TICKS; i++) {
      String numStr = str(floorToDecimalPlace(-i * MAX_TORQUE / spaces, 2));
      line(x, y + gap, x + tickLen, y + gap);
      text(numStr, x + textGap, y + gap);

      numStr = str(floorToDecimalPlace(i * MAX_TORQUE / spaces, 2));
      line(x, y - gap, x + tickLen, y - gap);
      text(numStr, x + textGap, y - gap);
      gap += spacing;
    }
    strokeWeight(1);
    textAlign(CENTER, CENTER);
  }

  void drawTorqueBrakeChart(float x, float y, float duration, float lastSpeed) {
    float[][] timeToTorque = page.torqueChartMapper.getTimeToTorque(motor.fw + "fw", "brake", abs(lastSpeed) + ">b");
    plot(x, y, duration, timeToTorque, lastSpeed < 0);
  }
  
  void drawTorqueBootChart(float x, float y, float duration, float currSpeed) {
    float[][] timeToTorque = page.torqueChartMapper.getTimeToTorque(motor.fw + "fw", "boot", "0>" + abs(currSpeed));
    plot(x, y, duration, timeToTorque, currSpeed < 0);
  }

  void drawTorqueHaltChart(float x, float y, float duration, float lastSpeed) {
    float[][] timeToTorque = page.torqueChartMapper.getTimeToTorque(motor.fw + "fw", "halt", abs(lastSpeed) + ">0");
    plot(x, y, duration, timeToTorque, lastSpeed < 0);
  }

  void drawTorqueLine() {
    List<Action> actions = motor.actions;
    float lineStartX = x;
    for (int i = 0; i < actions.size(); i++) {
      Action currAction = actions.get(i);
      ActionType currType = currAction.getType();
      float currSpeed = currAction.getSpeed();
      float lastSpeed = i == 0 ? 0 : actions.get(i - 1).getSpeed();
      float currDuration = currAction.getDuration();
      
      // TODO: don't pile up 💩 like this
      if (currType == ActionType.SPEED && currSpeed == 0) {
        drawTorqueHaltChart(lineStartX, y, currDuration, lastSpeed);
      } else if (currType == ActionType.ABSOLUTE) {
        if (lastSpeed == 0) {
          drawFlatLine(lineStartX, y, currDuration);
        } else {
          drawTorqueBrakeChart(lineStartX, y, currDuration, lastSpeed);
        }
      } else {
        // curr action is non-0 speed
        if (lastSpeed == 0) {
          drawTorqueBootChart(lineStartX, y, currDuration, currSpeed);
        } else if (lastSpeed * currSpeed < 0) {
          // what if it's shorter than 1
          if (currDuration <= 1) {
            drawFlatLine(lineStartX, y, currDuration);
          } else {
            drawFlatLine(lineStartX, y, 1.0);
            drawTorqueBootChart(lineStartX + timeManager.secondsToPixels(1.0), y, currDuration - 1.0, currSpeed);
          }
        } else {
          drawFlatLine(lineStartX, y, currDuration);
        }
      }
      lineStartX += timeManager.secondsToPixels(currDuration);
    }
  }
  
  void drawSelf() {
    if (!motor.drawer.showTorque) return;
    drawYTicks(x, y, page.torqueChartMapper.getMaxTorque(motor.fw + "fw"), LINE_CHART_VERTICAL_RANGE);
    drawTorqueLine();
  }
}
