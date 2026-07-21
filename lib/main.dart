import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/server_store.dart';
import 'services/v2ray_service.dart';
import 'services/settings_store.dart';
import 'services/ping_store.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GradelVpnApp());
}

class GradelVpnApp extends StatelessWidget {
  const GradelVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ServerStore()..loadFromDisk()),
        ChangeNotifierProvider(create: (_) => V2RayService()..init()),
        ChangeNotifierProvider(create: (_) => SettingsStore()..loadFromDisk()),
        ChangeNotifierProvider(create: (_) => PingStore()),
      ],
      child: MaterialApp(
        title: 'GradelVPN',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const GradientBackground(child: HomeScreen()),
      ),
    );
  }
}

/// Общий фон-градиент для всех экранов приложения — используется одной
/// обёрткой на верхнем уровне, чтобы не дублировать Container с градиентом
/// на каждом экране отдельно.
class GradientBackground extends StatelessWidget {
  final Widget child;
  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: child,
    );
  }
}
