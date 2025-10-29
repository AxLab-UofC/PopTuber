class ActionController {
  Button deleteButton;
  DurationSlider durationSlider;
  ActionController() {
    this.deleteButton = initDeleteButton();
    this.durationSlider = new DurationSlider();
  }

  void draw() {
    Action selectedAction = page.selectedAction;
    if (!page.state.canModify() || selectedAction == null) {
      hide();
      return;
    }
    show();
    float x = selectedAction.x;
    float y = selectedAction.y;
    float actionWidth = selectedAction.getWidth();
    deleteButton.setPosition(x + actionWidth - SLIDER_WIDTH - SMALL_ICON_SIZE, y + 1); // TODO: ???
    this.durationSlider.draw(x, y);
  }
  
  void show() {
    deleteButton.show();
    durationSlider.show();
  }
  
  void hide() {
    durationSlider.hide();
    deleteButton.hide();
  }
  
  Slider addSlider(String name, int x, int y, int width, float min, float max, int numTicks, String caption) {
    Slider slider = cp5.addSlider(name)
     .setPosition(x, y)
     .setWidth(width)
     .setRange(min, max)
     .setNumberOfTickMarks(numTicks)
     .setSliderMode(Slider.FLEXIBLE)
     .setColorForeground(color(207, 98, 67))
     .setColorBackground(color(40))
     .setColorActive(color(255, 138, 101));
    slider.getValueLabel().alignX(ControlP5.RIGHT).setPaddingX(0);
    slider.getCaptionLabel().alignX(ControlP5.LEFT).setPaddingX(0);
    if (!caption.isEmpty()) {
      slider.setCaptionLabel(caption);
    }
    return slider;
  }
  
  Button initDeleteButton() {
    return cp5.addButton("actionDeleteButton")
     .setPosition( -200, -200) // out of screen
     .setImage(minusIcon).setSize(SMALL_ICON_SIZE, SMALL_ICON_SIZE)
     .addListener(new ControlListener() {
      public void controlEvent(ControlEvent event) {
        if (!page.state.canModify() || page.selectedAction == null) return;
        if (event.getName().equals("actionDeleteButton")) {
          page.selectedAction.motor.removeAction(page.selectedAction);
          page.selectedAction = null;
          hide();
        }
      }
    });
  }
}

class DurationSlider {
  boolean showing = false;
  DurationSlider() {}
  void show() {
    this.showing = true;
  }
  void hide() {
    this.showing = false;
  }
  
  boolean isMouseOver() {
    Action selectedAction = page.selectedAction;
    if (!showing || !page.state.canModify() || selectedAction == null) return false;
    float y = selectedAction.y;
    float endX = selectedAction.getWidth() + selectedAction.x;
    if (mouseX > endX - SLIDER_WIDTH 
      && mouseX < endX
      && mouseY > y
      && mouseY < y + ROW_HEIGHT) return true;
    return false;
  }
  
  void draw(float x, float y) {
    Action selectedAction = page.selectedAction;
    if (!showing || !page.state.canModify() || selectedAction == null) return;
    float endX = selectedAction.getWidth() + selectedAction.x;
    fill(getGrey());
    stroke(getBlack());
    strokeWeight(1);
    rect(endX - SLIDER_WIDTH, y, SLIDER_WIDTH, ROW_HEIGHT);
    fill(255);
  }

  boolean locked;
  float xOffset = 0;
  float yOffset = 0;
}

Action findClickedAction() {
  for (Motor motor : page.motors) {
    for (Action action : motor.getActions()) {
      if (action.isMouseOver()) {
        return action;
      }
    }
  }
  return null;
}

void actionScrollHandler(int e) {
  if (!page.state.canModify()) return;
  Action selectedAction = page.selectedAction;
  if (selectedAction != null && selectedAction.type == ActionType.SPEED) {
    float currSpeed = selectedAction.getSpeed();
    float newSpeed = currSpeed + (e) * 1;
    if (newSpeed >= 253) {
      newSpeed = 253;
    } else if (newSpeed <= -253) {
      newSpeed = -253;
    } 
    if (newSpeed != selectedAction.getSpeed()) {
      selectedAction.setSpeed(newSpeed);
    }
  }
}

// press up and down keys to fine tune the speed
void speedChangeHandler() {
  if (!page.state.canModify()) return;
  Action selectedAction = page.selectedAction;
  if (selectedAction != null && selectedAction.type == ActionType.SPEED) {
    float currSpeed = selectedAction.getSpeed();
    float newSpeed = currSpeed;

    // Handling key events
    if (keyCode == UP) {
        newSpeed += 1; // Increase speed by 25
    } else if (keyCode == DOWN) {
        newSpeed -= 1; // Decrease speed by 25
    }

    // Clamp speed between -100 and 100
    newSpeed = Math.min(100, Math.max(-100, newSpeed));

    // Update speed if it has changed
    if (newSpeed != selectedAction.getSpeed()) {
      selectedAction.setSpeed(newSpeed);
    }
  }
}

void shiftAction(Action action) {
  Motor oldMotor = action.motor;
  int motorId = oldMotor.id;
  int actionPos = oldMotor.actions.indexOf(action);
  if (keyCode == UP && motorId > 0) {
    Motor destMotor = page.motors.get(motorId - 1);
    float startTime = oldMotor.getActionStartTime(action);
    oldMotor.removeAction(action);
    destMotor.insertAction(action, destMotor.findIndexToInsert(startTime));
  } else if (keyCode == DOWN && motorId < page.motors.size() - 1) {
    Motor destMotor = page.motors.get(motorId + 1);
    float startTime = oldMotor.getActionStartTime(action);
    oldMotor.removeAction(action);
    destMotor.insertAction(action, destMotor.findIndexToInsert(startTime));
  } else if (keyCode == LEFT && actionPos > 0) {
    oldMotor.insertAction(oldMotor.removeAction(action), actionPos - 1);
  } else if (keyCode == RIGHT && actionPos < oldMotor.actions.size() - 1) {
    oldMotor.insertAction(oldMotor.removeAction(action), actionPos + 1);
  }
}
