class ClickManager {

  final Set<Clickable> clickables;
  ClickManager() {
     this.clickables = new HashSet<>();
  }

  void subscribe(Clickable c) {
    this.clickables.add(c);
  }

  void unsubscribe(Clickable c) {
    this.clickables.remove(c);
  }

  List<Clickable> applyClick() {
    List<Clickable> clicked = new ArrayList<>();
    for (Clickable c : this.clickables) {
      if (c.isMouseOver()) {
        c.onClick();
        clicked.add(c);
      }
    }
    return clicked;
  }
}

interface Clickable {
  void onClick();
  boolean isMouseOver();
}
