import 'package:flutter/material.dart';
import 'local_secure_store.dart';

class SessionController extends ChangeNotifier {
  bool _ready = false;
  bool _signedIn = false;
  bool _briefingCompleted = false;
  String? _email;
  ThemeMode _themeMode = ThemeMode.system;
  dynamic liveSync; // Hold LiveSyncController (dynamic to avoid circular dependency)

  bool get ready => _ready;
  bool get signedIn => _signedIn;
  bool get briefingCompleted => _briefingCompleted;
  String? get email => _email;
  ThemeMode get themeMode => _themeMode;

  void setBriefingCompleted(bool v) {
    _briefingCompleted = v;
    notifyListeners();
  }

  void setReady(bool v) {
    _ready = v;
    notifyListeners();
  }

  void setSignedIn(bool v, {String? email}) {
    _signedIn = v;
    _email = email;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  Future<void> signOut() async {
    await LocalSecureStore.instance.clearSession();
    setSignedIn(false, email: null);
  }
}
