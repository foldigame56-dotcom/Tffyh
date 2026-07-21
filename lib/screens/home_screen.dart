import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray_client/flutter_v2ray.dart';
import 'package:provider/provider.dart';
import '../services/server_store.dart';
import '../services/v2ray_service.dart';
import '../services/settings_store.dart';
import '../services/ping_store.dart';
import '../theme/app_theme.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _busy = false;
  String _statusText = '';
  bool _autoConnectTried = false;

  // Раньше кнопка была статичным кругом без единой анимации ни в
  // состоянии "подключаюсь", ни в "подключено" — отсюда ощущение, что
  // анимации "недоработаны". Этот контроллер крутит мягкое дыхание
  // (масштаб + прозрачность внешнего кольца), которое ускоряется во
  // время подключения и медленно идёт, когда VPN уже активен.
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  // Канал в MainActivity.kt — плитка в шторке не может напрямую дёрнуть
  // Dart-код, пока движок Flutter не поднят, поэтому она просто открывает
  // приложение с пометкой "нажали плитку" (см. android-overlay/), а тут
  // при старте мы её забираем и сразу подключаемся к лучшему серверу.
  static const _quickConnectChannel = MethodChannel('com.gradelvpn/quick_connect');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final fromTile = await _takePendingQuickConnect();
      if (fromTile) {
        await _quickConnectBestServer();
      } else {
        await _maybeAutoConnect();
      }
    });
  }

  Future<bool> _takePendingQuickConnect() async {
    try {
      final result = await _quickConnectChannel.invokeMethod<bool>(
        'takePendingQuickConnect',
      );
      return result ?? false;
    } catch (_) {
      return false; // канал недоступен (например, при разработке/тестах)
    }
  }

  /// То же самое, что и обычный автовыбор + подключение, только форсирует
  /// режим "автовыбор" на этот единственный запуск, даже если у
  /// пользователя выбран конкретный сервер вручную — так и задумано для
  /// плитки: она всегда бьёт по всем серверам и берёт лучший.
  Future<void> _quickConnectBestServer() async {
    final store = context.read<ServerStore>();
    if (!store.autoSelectEnabled) {
      await store.setAutoSelect(true);
    }
    if (!mounted) return;
    await _toggle();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _maybeAutoConnect() async {
    if (_autoConnectTried) return;
    _autoConnectTried = true;
    final settings = context.read<SettingsStore>();
    final store = context.read<ServerStore>();
    final v2ray = context.read<V2RayService>();
    final hasTarget = store.autoSelectEnabled || store.selectedServer != null;
    if (settings.autoConnect && hasTarget && !v2ray.isConnected) {
      await _toggle();
    }
  }

  String _remarkFor(String link) {
    try {
      final parsed = V2ray.parseFromURL(link);
      return parsed.remark.isNotEmpty ? parsed.remark : 'Сервер';
    } catch (_) {
      return 'Сервер';
    }
  }

  Future<void> _toggle() async {
    final v2ray = context.read<V2RayService>();
    final store = context.read<ServerStore>();
    final settings = context.read<SettingsStore>();
    final pingStore = context.read<PingStore>();

    if (v2ray.isConnected) {
      setState(() => _busy = true);
      await v2ray.disconnect();
      setState(() {
        _busy = false;
        _statusText = '';
      });
      return;
    }

    String? target = store.selectedServer;

    if (store.autoSelectEnabled) {
      if (store.servers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Список серверов пуст')),
        );
        return;
      }
      setState(() {
        _busy = true;
        _statusText = 'Проверяю все сервера...';
      });
      target = await pingStore.findBest(store.servers);
      if (target == null) {
        setState(() {
          _busy = false;
          _statusText = '';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ни один сервер не ответил, попробуй позже')),
          );
        }
        return;
      }
      store.setAutoSelectedLink(target);
    } else if (target == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выбери сервер')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _statusText = 'Подключаюсь...';
    });
    final granted = await v2ray.requestPermission();
    if (!granted) {
      setState(() {
        _busy = false;
        _statusText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужно разрешение на VPN-соединение')),
        );
      }
      return;
    }
    try {
      await v2ray.connect(target, settings: settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
    setState(() {
      _busy = false;
      _statusText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final v2ray = context.watch<V2RayService>();
    final store = context.watch<ServerStore>();
    final connected = v2ray.isConnected;

    _pulseController.duration = _busy
        ? const Duration(milliseconds: 700) // быстрее — идёт подключение
        : const Duration(milliseconds: 1800); // медленнее — просто дышит

    final String currentServerLabel;
    if (store.autoSelectEnabled) {
      currentServerLabel = store.autoSelectedLink != null
          ? '⚡ ${_remarkFor(store.autoSelectedLink!)} (авто)'
          : '⚡ Автовыбор';
    } else if (store.selectedServer != null) {
      currentServerLabel = _remarkFor(store.selectedServer!);
    } else {
      currentServerLabel = 'Сервер не выбран';
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'GradelVPN',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: _busy ? null : _toggle,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final t = _pulseController.value; // 0 → 1 → 0
                  final ringColor =
                      connected ? AppTheme.connectedGreen : AppTheme.electricBlue;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Внешнее дышащее кольцо — расширяется и растворяется.
                      Container(
                        width: 190 + t * 34,
                        height: 190 + t * 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ringColor.withOpacity(0.35 * (1 - t)),
                            width: 2,
                          ),
                        ),
                      ),
                      child!,
                    ],
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: connected
                        ? AppTheme.connectedGradient
                        : AppTheme.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (connected
                                ? AppTheme.connectedGreen
                                : AppTheme.electricBlue)
                            .withOpacity(0.45),
                        blurRadius: 40,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _busy
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            Icons.power_settings_new,
                            size: 68,
                            color: Colors.white,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _busy
                  ? _statusText.isNotEmpty
                      ? _statusText.toUpperCase()
                      : 'ПОДКЛЮЧЕНИЕ...'
                  : connected
                      ? 'ПОДКЛЮЧЕНО'
                      : 'ОТКЛЮЧЕНО',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: connected ? AppTheme.connectedGreen : Colors.grey,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (connected) ...[
              const SizedBox(height: 6),
              Text(
                currentServerLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.surface,
                          AppTheme.surfaceLight.withOpacity(0.6),
                        ],
                      ),
                      border: Border.all(
                        color: store.autoSelectEnabled
                            ? AppTheme.gold
                            : AppTheme.surfaceLight,
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Icon(
                        store.autoSelectEnabled
                            ? Icons.bolt_rounded
                            : Icons.dns_rounded,
                        color:
                            store.autoSelectEnabled ? AppTheme.gold : AppTheme.cyan,
                      ),
                      title: Text(currentServerLabel),
                      subtitle: Text('${store.servers.length} серверов доступно'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ServersScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          icon: Icons.upload_rounded,
                          label: 'Отдано',
                          value: _formatSpeed(v2ray.status.uploadSpeed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.download_rounded,
                          label: 'Получено',
                          value: _formatSpeed(v2ray.status.downloadSpeed),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _StatChip(
                          icon: Icons.timer_outlined,
                          label: 'Время',
                          value: v2ray.status.duration.isNotEmpty
                              ? v2ray.status.duration
                              : '—',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatSpeed(int? bytesPerSecond) {
    final v = bytesPerSecond ?? 0;
    if (v <= 0) return '0 Кб/с';
    if (v >= 1024 * 1024) {
      return '${(v / (1024 * 1024)).toStringAsFixed(1)} Мб/с';
    }
    return '${(v / 1024).toStringAsFixed(0)} Кб/с';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.cyan),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
