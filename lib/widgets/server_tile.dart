import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import '../theme/app_theme.dart';

class ServerTile extends StatelessWidget {
  final String link;
  final bool selected;
  final int? pingMs; // null = ещё не проверяли, -1 = недоступен
  final bool pinging;
  final VoidCallback onTap;
  final VoidCallback onPing;

  const ServerTile({
    super.key,
    required this.link,
    required this.selected,
    required this.pingMs,
    required this.pinging,
    required this.onTap,
    required this.onPing,
  });

  String get _remark {
    try {
      final parsed = FlutterV2ray.parseFromURL(link);
      return parsed.remark.isNotEmpty ? parsed.remark : link;
    } catch (_) {
      return link;
    }
  }

  Color _pingColor() {
    if (pingMs == null) return Colors.grey;
    if (pingMs == -1) return AppTheme.danger;
    if (pingMs! < 150) return AppTheme.connectedGreen;
    if (pingMs! < 400) return AppTheme.gold;
    return AppTheme.danger;
  }

  String _pingText() {
    if (pinging) return '...';
    if (pingMs == null) return '';
    if (pingMs == -1) return 'нет связи';
    return '$pingMs мс';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppTheme.cyan : AppTheme.surfaceLight,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            key: ValueKey(selected),
            color: selected ? AppTheme.cyan : Colors.grey,
          ),
        ),
        title: Text(_remark, overflow: TextOverflow.ellipsis),
        trailing: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: pinging
              ? const SizedBox(
                  key: ValueKey('spinner'),
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  key: ValueKey('ping-${pingMs ?? 'none'}'),
                  onPressed: onPing,
                  child: Text(
                    _pingText().isEmpty ? 'ping' : _pingText(),
                    style: TextStyle(color: _pingColor()),
                  ),
                ),
        ),
      ),
    );
  }
}
