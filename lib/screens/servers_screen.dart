import 'package:flutter/material.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/ping_store.dart';
import '../theme/app_theme.dart';
import '../widgets/server_tile.dart';
import 'subscription_screen.dart';

class ServersScreen extends StatelessWidget {
  const ServersScreen({super.key});

  String _formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} МБ';
  }

  String _remarkFor(String link) {
    try {
      final parsed = V2ray.parseFromURL(link);
      return parsed.remark.isNotEmpty ? parsed.remark : link;
    } catch (_) {
      return link;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ServerStore>();
    final pingStore = context.watch<PingStore>();
    final hasSubInfo = store.subscriptionTitle != null ||
        store.trafficTotalBytes != null ||
        store.expiresAt != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Серверы'),
        actions: [
          IconButton(
            tooltip: 'Проверить все серверы',
            icon: pingStore.pingingAll
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            onPressed: (pingStore.pingingAll || store.servers.isEmpty)
                ? null
                : () => pingStore.pingAll(store.servers),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.refreshServers,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            if (hasSubInfo)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: AppTheme.accentGradient,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (store.subscriptionTitle != null)
                        Text(
                          store.subscriptionTitle!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (store.trafficTotalBytes != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Трафик: ${_formatBytes(store.trafficUsedBytes)} из ${_formatBytes(store.trafficTotalBytes)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: (store.trafficUsedBytes ?? 0) /
                                (store.trafficTotalBytes ?? 1),
                            backgroundColor: Colors.white24,
                            color: Colors.white,
                            minHeight: 6,
                          ),
                        ),
                      ],
                      if (store.expiresAt != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Действует до: ${store.expiresAt!.day.toString().padLeft(2, '0')}.${store.expiresAt!.month.toString().padLeft(2, '0')}.${store.expiresAt!.year}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (store.servers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => store.setAutoSelect(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AppTheme.gold.withOpacity(0.1),
                        border: Border.all(
                          color: AppTheme.gold,
                          width: store.autoSelectEnabled ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            store.autoSelectEnabled
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: AppTheme.gold,
                          ),
                          const SizedBox(width: 12),
                          pingStore.autoSelecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.gold,
                                  ),
                                )
                              : const Icon(Icons.bolt_rounded,
                                  color: AppTheme.gold),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Автовыбор лучшего сервера',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.gold,
                                  ),
                                ),
                                Text(
                                  pingStore.autoSelecting
                                      ? 'Проверяю все сервера...'
                                      : 'При каждом подключении сам выберет самый быстрый',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (store.servers.isEmpty)
              Column(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.cloud_off, size: 48, color: Colors.grey.shade600),
                  const SizedBox(height: 12),
                  const Center(child: Text('Список серверов пуст')),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SubscriptionScreen(),
                        ),
                      ),
                      child: const Text('Добавить подписку'),
                    ),
                  ),
                ],
              )
            else
              ...store.servers.map((link) => ServerTile(
                    link: link,
                    selected:
                        !store.autoSelectEnabled && store.selectedServer == link,
                    pingMs: pingStore.pings[link],
                    pinging: pingStore.pinging.contains(link),
                    onTap: () => store.selectServer(link),
                    onPing: () => pingStore.pingOne(link),
                  )),
          ],
        ),
      ),
    );
  }
}
