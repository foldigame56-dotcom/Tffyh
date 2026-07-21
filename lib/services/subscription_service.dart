import 'dart:convert';
import 'package:http/http.dart' as http;

/// Схемы, которые реально умеет подключать flutter_v2ray. Всё остальное
/// (например, ссылка на support-чат или канал, которую некоторые панели
/// зачем-то кладут прямо в тело подписки) — не сервер и должно отсеиваться.
const _supportedSchemes = ['vless://', 'vmess://', 'trojan://', 'ss://', 'socks://'];

/// Метаданные подписки, которые многие панели (3x-ui, Marzban) отдают
/// через HTTP-заголовки ответа вместе со списком серверов:
/// - profile-title — название подписки (обычно в base64)
/// - subscription-userinfo — использованный/общий трафик и дата истечения
class SubscriptionInfo {
  final String? title;
  final int? trafficUsedBytes;
  final int? trafficTotalBytes;
  final DateTime? expiresAt;

  const SubscriptionInfo({
    this.title,
    this.trafficUsedBytes,
    this.trafficTotalBytes,
    this.expiresAt,
  });

  bool get hasData =>
      title != null || trafficTotalBytes != null || expiresAt != null;
}

class SubscriptionResult {
  final List<String> servers;
  final SubscriptionInfo info;
  const SubscriptionResult(this.servers, this.info);
}

class SubscriptionService {
  static Future<SubscriptionResult> fetchServers(String subscriptionUrl) async {
    final uri = Uri.tryParse(subscriptionUrl.trim());
    if (uri == null) {
      throw const FormatException('Некорректная ссылка на подписку');
    }

    final response = await http
        .get(uri, headers: {'User-Agent': 'v2rayNG/1.8.0'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception('Сервер вернул ошибку ${response.statusCode}');
    }

    final body = response.body.trim();
    String decoded;
    try {
      decoded = utf8.decode(base64.decode(base64.normalize(body)));
    } catch (_) {
      // Если это не base64 — считаем, что бот уже отдал список ссылок текстом.
      decoded = body;
    }

    final servers = decoded
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) {
          if (line.isEmpty) return false;
          final lower = line.toLowerCase();
          return _supportedSchemes.any((scheme) => lower.startsWith(scheme));
        })
        .toList();

    if (servers.isEmpty) {
      throw Exception('В подписке не найдено ни одного рабочего сервера');
    }

    final info = _parseHeaders(response.headers);
    return SubscriptionResult(servers, info);
  }

  static SubscriptionInfo _parseHeaders(Map<String, String> headers) {
    String? title;
    final rawTitle = headers['profile-title'];
    if (rawTitle != null) {
      try {
        title = utf8.decode(base64.decode(base64.normalize(rawTitle)));
      } catch (_) {
        title = rawTitle;
      }
    }

    int? used;
    int? total;
    DateTime? expires;
    final userInfo = headers['subscription-userinfo'];
    if (userInfo != null) {
      // Формат: "upload=123; download=456; total=789; expire=1735689600"
      final parts = userInfo.split(';');
      final map = <String, String>{};
      for (final part in parts) {
        final kv = part.trim().split('=');
        if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
      }
      final upload = int.tryParse(map['upload'] ?? '') ?? 0;
      final download = int.tryParse(map['download'] ?? '') ?? 0;
      used = upload + download;
      total = int.tryParse(map['total'] ?? '');
      final expireEpoch = int.tryParse(map['expire'] ?? '');
      if (expireEpoch != null && expireEpoch > 0) {
        expires = DateTime.fromMillisecondsSinceEpoch(expireEpoch * 1000);
      }
    }

    return SubscriptionInfo(
      title: title,
      trafficUsedBytes: used,
      trafficTotalBytes: (total != null && total > 0) ? total : null,
      expiresAt: expires,
    );
  }
}
