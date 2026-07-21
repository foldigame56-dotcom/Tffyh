import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

const _kSubUrlKey = 'subscription_url';
const _kServersKey = 'servers_list';
const _kSelectedKey = 'selected_server';
const _kAutoSelectKey = 'auto_select_enabled';
const _kTitleKey = 'sub_title';
const _kUsedKey = 'sub_used';
const _kTotalKey = 'sub_total';
const _kExpireKey = 'sub_expire';

/// Хранит ссылку на подписку (которую выдаёт бот), список серверов и
/// метаданные подписки (название, трафик, срок действия). Переживает
/// перезапуск приложения.
class ServerStore extends ChangeNotifier {
  String? subscriptionUrl;
  List<String> servers = [];
  String? selectedServer;
  bool autoSelectEnabled = false;
  // Не сохраняется на диск — просто для отображения, какой сервер был
  // выбран автовыбором при последнем подключении.
  String? autoSelectedLink;
  bool loading = false;
  String? lastError;

  String? subscriptionTitle;
  int? trafficUsedBytes;
  int? trafficTotalBytes;
  DateTime? expiresAt;

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    subscriptionUrl = prefs.getString(_kSubUrlKey);
    servers = prefs.getStringList(_kServersKey) ?? [];
    selectedServer = prefs.getString(_kSelectedKey);
    autoSelectEnabled = prefs.getBool(_kAutoSelectKey) ?? false;
    subscriptionTitle = prefs.getString(_kTitleKey);
    trafficUsedBytes = prefs.getInt(_kUsedKey);
    trafficTotalBytes = prefs.getInt(_kTotalKey);
    final expireMs = prefs.getInt(_kExpireKey);
    expiresAt = expireMs != null
        ? DateTime.fromMillisecondsSinceEpoch(expireMs)
        : null;
    notifyListeners();
  }

  Future<void> setSubscriptionUrl(String url) async {
    subscriptionUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSubUrlKey, url);
    notifyListeners();
  }

  Future<void> refreshServers() async {
    if (subscriptionUrl == null || subscriptionUrl!.isEmpty) {
      lastError = 'Сначала добавь ссылку на подписку от бота';
      notifyListeners();
      return;
    }
    loading = true;
    lastError = null;
    notifyListeners();
    try {
      final result = await SubscriptionService.fetchServers(subscriptionUrl!);
      servers = result.servers;
      subscriptionTitle = result.info.title;
      trafficUsedBytes = result.info.trafficUsedBytes;
      trafficTotalBytes = result.info.trafficTotalBytes;
      expiresAt = result.info.expiresAt;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kServersKey, servers);
      if (subscriptionTitle != null) {
        await prefs.setString(_kTitleKey, subscriptionTitle!);
      }
      if (trafficUsedBytes != null) {
        await prefs.setInt(_kUsedKey, trafficUsedBytes!);
      }
      if (trafficTotalBytes != null) {
        await prefs.setInt(_kTotalKey, trafficTotalBytes!);
      }
      if (expiresAt != null) {
        await prefs.setInt(_kExpireKey, expiresAt!.millisecondsSinceEpoch);
      }

      if (selectedServer != null && !servers.contains(selectedServer)) {
        selectedServer = null;
        await prefs.remove(_kSelectedKey);
      }
    } catch (e) {
      lastError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> selectServer(String link) async {
    selectedServer = link;
    autoSelectEnabled = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedKey, link);
    await prefs.setBool(_kAutoSelectKey, false);
    notifyListeners();
  }

  /// Включает/выключает режим "автовыбор" — при подключении будет
  /// пингован весь список и выбран сервер с минимальной задержкой,
  /// заново при каждом подключении (а не один раз навсегда).
  Future<void> setAutoSelect(bool enabled) async {
    autoSelectEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoSelectKey, enabled);
    notifyListeners();
  }

  void setAutoSelectedLink(String? link) {
    autoSelectedLink = link;
    notifyListeners();
  }
}
