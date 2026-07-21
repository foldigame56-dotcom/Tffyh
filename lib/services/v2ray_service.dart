import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_store.dart';

/// Обёртка над flutter_v2ray_client, которая держит состояние подключения
/// и уведомляет UI через ChangeNotifier.
///
/// Раньше здесь использовался пакет `flutter_v2ray` (blueboy-tm) — в нём
/// кастомная иконка уведомления (notificationIconResourceName) фактически
/// не работала независимо от того, что ей передать: сколько ни меняй имя
/// ресурса в pubspec.yaml, в шторке всё равно оставался дефолтный логотип
/// Flutter. `flutter_v2ray_client` — активно поддерживаемый форк того же
/// плагина (тот же API, тот же Xray-core под капотом), где этот же самый
/// параметр отдельно указан в их фичах как рабочий/починенный.
///
/// Проверка пинга серверов теперь живёт отдельно в PingStore (быстрый
/// TCP-пинг) — этот класс отвечает только за само VPN-соединение.
class V2RayService extends ChangeNotifier {
  late final V2ray _v2ray;
  bool _initialized = false;

  V2RayStatus status = V2RayStatus();
  String? connectedRemark;

  V2RayService() {
    _v2ray = V2ray(
      onStatusChanged: (s) {
        status = s;
        notifyListeners();
      },
    );
  }

  Future<void> init() async {
    if (_initialized) return;
    await _v2ray.initialize(
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
    final parsed = V2ray.parseFromURL(shareLink);
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
