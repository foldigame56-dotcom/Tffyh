import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kBypassLanKey = 'settings_bypass_lan';
const _kAutoConnectKey = 'settings_auto_connect';

/// Список локальных подсетей, которые не нужно пускать через VPN —
/// чтобы домашний Wi-Fi, принтеры и локальные устройства оставались
/// доступны напрямую, пока включён VPN.
const List<String> lanBypassSubnets = [
  "0.0.0.0/5", "8.0.0.0/7", "11.0.0.0/8", "12.0.0.0/6", "16.0.0.0/4",
  "32.0.0.0/3", "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5", "168.0.0.0/6",
  "172.0.0.0/12", "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9",
  "173.0.0.0/8", "174.0.0.0/7", "176.0.0.0/4", "192.0.0.0/9",
  "192.128.0.0/11", "192.160.0.0/13", "192.169.0.0/16", "192.170.0.0/15",
  "192.172.0.0/14", "192.176.0.0/12", "192.192.0.0/10", "193.0.0.0/8",
  "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4", "240.0.0.0/4",
];

/// Настройки самого VPN-клиента (не связаны с подпиской/серверами).
/// Переживают перезапуск приложения.
class SettingsStore extends ChangeNotifier {
  bool bypassLan = false;
  bool autoConnect = false;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    bypassLan = prefs.getBool(_kBypassLanKey) ?? false;
    autoConnect = prefs.getBool(_kAutoConnectKey) ?? false;
    notifyListeners();
  }

  Future<void> setBypassLan(bool value) async {
    bypassLan = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBypassLanKey, value);
    notifyListeners();
  }

  Future<void> setAutoConnect(bool value) async {
    autoConnect = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoConnectKey, value);
    notifyListeners();
  }
}
