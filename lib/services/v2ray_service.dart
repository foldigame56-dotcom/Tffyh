import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_store.dart';

/// Обёртка над flutter_v2ray, которая держит состояние подключения
/// и уведомляет UI через ChangeNotifier.
///
/// Проверка пинга серверов теперь живёт отдельно в PingStore (быстрый
/// TCP-пинг) — этот класс отвечает только за само VPN-соединение.
class V2RayService extends ChangeNotifier {
  late final FlutterV2ray _v2ray;
  bool _initialized = false;

  V2RayStatus status = V2RayStatus();
  String? connectedRemark;

  V2RayService() {
    _v2ray = FlutterV2ray(
      onStatusChanged: (s) {
        status = s;
        notifyListeners();
      },
    );
  }

  Future<void> init() async {
    if (_initialized) return;
    // По умолчанию плагин ищет иконку для уведомления по имени
    // mipmap/ic_launcher — но flutter_launcher_icons в этом проекте
    // настроен генерировать иконку под именем launcher_icon (см.
    // pubspec.yaml), поэтому ic_launcher так и остаётся дефолтным
    // логотипом Flutter, который плагин и показывал в уведомлении.
    await _v2ray.initializeV2Ray(
      notificationIconResourceType: 'mipmap',
      notificationIconResourceName: 'ic_launcher',
    );
    _initialized = true;
  }

  /// Показывает системный диалог "Разрешить приложению создавать VPN-соединения".
  /// Нужно вызвать один раз перед первым подключением.
  ///
  /// На Android 13+ (API 33) уведомления требуют ОТДЕЛЬНОГО runtime-разрешения
  /// (POST_NOTIFICATIONS). Если его не запросить, система молча блокирует
  /// собственное уведомление плагина (иконка + "подключено к <сервер>" +
  /// кнопка отключения) — и остаётся только обязательное системное
  /// уведомление Android о работе VPN с общим текстом, без деталей. Поэтому
  /// разрешение на уведомления запрашивается здесь же, до/вместе с VPN-разрешением.
  Future<bool> requestPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    return _v2ray.requestPermission();
  }

  Future<void> connect(String shareLink, {SettingsStore? settings}) async {
    final parsed = FlutterV2ray.parseFromURL(shareLink);
    connectedRemark = parsed.remark.isNotEmpty ? parsed.remark : 'VPN';
    await _v2ray.startV2Ray(
      remark: connectedRemark!,
      config: parsed.getFullConfiguration(),
      bypassSubnets: (settings?.bypassLan ?? false) ? lanBypassSubnets : null,
      notificationDisconnectButtonName: 'ОТКЛЮЧИТЬ',
    );
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _v2ray.stopV2Ray();
    connectedRemark = null;
    notifyListeners();
  }

  bool get isConnected => status.state == 'CONNECTED';
}
