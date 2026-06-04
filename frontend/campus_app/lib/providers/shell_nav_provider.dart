import 'package:flutter/foundation.dart';

class ShellNavProvider extends ChangeNotifier {
  int index = 0;

  void goTo(int tabIndex) {
    if (index == tabIndex) return;
    index = tabIndex;
    notifyListeners();
  }
}
