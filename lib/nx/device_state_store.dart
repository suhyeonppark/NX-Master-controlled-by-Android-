import 'package:flutter/foundation.dart';

class DeviceStateStore extends ChangeNotifier {
  final Map<int, bool> _relays = {};
  final Map<String, bool> _ios = {};
  final Map<int, String> _serial = {};

  bool? relay(int ch) => _relays[ch];

  bool? io(int port, int ch) => _ios[_ioKey(port, ch)];

  String? serial(int port) => _serial[port];

  Map<int, String> get serialMessages => Map.unmodifiable(_serial);

  void setRelay(int ch, bool value) {
    if (_relays[ch] == value) return;
    _relays[ch] = value;
    notifyListeners();
  }

  void setIo(int port, int ch, bool value) {
    final key = _ioKey(port, ch);
    if (_ios[key] == value) return;
    _ios[key] = value;
    notifyListeners();
  }

  void setSerial(int port, String message) {
    _serial[port] = message;
    notifyListeners();
  }

  void clearDigitalStates() {
    _relays.clear();
    _ios.clear();
    notifyListeners();
  }

  String _ioKey(int port, int ch) => '$port:$ch';
}
