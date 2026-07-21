import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Быстрая проверка доступности серверов — TCP-пинг (время установки
/// сетевого соединения до хоста:порта сервера), а не полный прогон через
/// VPN-ядро. Это ровно то, как делают быстрые проверки в других клиентах
/// (в v2rayN это называется "TCPing" в отличие от медленного "Real Ping") —
/// на порядок быстрее и, в отличие от прогона через V2Ray-ядро, спокойно
/// выполняется полностью параллельно без конфликтов портов.
///
/// Живёт как отдельный провайдер (а не состояние экрана), поэтому проверка
/// продолжается и результат сохраняется, даже если случайно уйти с экрана
/// серверов на главный и вернуться обратно.
class PingStore extends ChangeNotifier {
  final Map<String, int> pings = {};
  final Set<String> pinging = {};
  bool pingingAll = false;
  bool autoSelecting = false;

  Future<int> pingOne(String link) async {
    pinging.add(link);
    notifyListeners();

    final hostPort = _extractHostPort(link);
    int result = -1;
    if (hostPort != null) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          hostPort.host,
          hostPort.port,
          timeout: const Duration(seconds: 5),
        );
        sw.stop();
        result = sw.elapsedMilliseconds;
        socket.destroy();

        // Ниже ~2 мс TCP-рукопожатие до внешнего интернет-хоста физически
        // невозможно (это уже время реакции локальной петли). Если сюда
        // попали — значит соединение на самом деле ушло не туда, куда
        // должно: либо это адрес из локальной/частной сети (127.0.0.1,
        // 10.x, 192.168.x и т.д. — например, если в ссылке сервера
        // случайно оказался локальный адрес), либо сокет перехватил уже
        // включённый на устройстве системный VPN/прокси (см. v2RayTun /
        // другой профиль в шторке — тогда ping меряет время до ЕГО
        // локального интерфейса, а не до настоящего сервера).
        //
        // Отдельно от этого: у серверов за CDN (Cloudflare и т.п., когда
        // хост в ссылке — это домен-фронт, а не сам бэкенд) честный TCP-пинг
        // будет мерить время до ближайшей точки CDN, а не до реального
        // сервера — и тоже может выглядеть подозрительно низким. Это не
        // баг измерения, а свойство самой конфигурации; узнать реальную
        // задержку до бэкенда можно только соединением через сам V2Ray-ядро
        // ("настоящий" пинг), а не голым TCP.
        if (result < 2 || _isPrivateOrLoopback(hostPort.host)) {
          result = -1;
        }
      } catch (_) {
        result = -1;
      }
    }

    pings[link] = result;
    pinging.remove(link);
    notifyListeners();
    return result;
  }

  Future<void> pingAll(List<String> links) async {
    pingingAll = true;
    notifyListeners();
    await Future.wait(links.map(pingOne));
    pingingAll = false;
    notifyListeners();
  }

  /// Пингует все сервера и возвращает ссылку на тот, где меньше всего
  /// задержка (или null, если ни один не ответил).
  Future<String?> findBest(List<String> links) async {
    autoSelecting = true;
    notifyListeners();
    await Future.wait(links.map(pingOne));
    autoSelecting = false;
    notifyListeners();

    String? best;
    int bestPing = 1 << 30;
    for (final link in links) {
      final ping = pings[link];
      if (ping != null && ping > 0 && ping < bestPing) {
        bestPing = ping;
        best = link;
      }
    }
    return best;
  }
}

bool _isPrivateOrLoopback(String host) {
  final ip = InternetAddress.tryParse(host);
  if (ip == null) return false; // домен — резолвится системой, не наш случай
  if (ip.isLoopback) return true;
  if (ip.type == InternetAddressType.IPv4) {
    final o = ip.rawAddress;
    if (o[0] == 10) return true;
    if (o[0] == 172 && o[1] >= 16 && o[1] <= 31) return true;
    if (o[0] == 192 && o[1] == 168) return true;
    if (o[0] == 169 && o[1] == 254) return true;
  }
  return false;
}

class _HostPort {
  final String host;
  final int port;
  const _HostPort(this.host, this.port);
}

_HostPort? _extractHostPort(String link) {
  try {
    if (link.toLowerCase().startsWith('vmess://')) {
      final payload = link.substring('vmess://'.length).split('#').first;
      final decoded = utf8.decode(base64.decode(base64.normalize(payload)));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final host = json['add']?.toString();
      final port = int.tryParse(json['port']?.toString() ?? '');
      if (host != null && port != null) return _HostPort(host, port);
      return null;
    }

    // vless://, trojan://, ss:// (SIP002 формат) — обычный URI.
    final uri = Uri.parse(link);
    if (uri.host.isNotEmpty && uri.hasPort) {
      return _HostPort(uri.host, uri.port);
    }

    // Старый формат ss://BASE64(method:password@host:port)
    if (link.toLowerCase().startsWith('ss://')) {
      final payload = link.substring('ss://'.length).split('#').first;
      final decoded = utf8.decode(base64.decode(base64.normalize(payload)));
      final match = RegExp(r'@([^:/?#]+):(\d+)').firstMatch(decoded);
      if (match != null) {
        return _HostPort(match.group(1)!, int.parse(match.group(2)!));
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}
