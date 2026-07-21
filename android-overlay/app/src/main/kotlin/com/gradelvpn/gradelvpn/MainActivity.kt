package com.gradelvpn.gradelvpn

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * По умолчанию flutter_v2ray работает через свой собственный MainActivity,
 * который создаёт `flutter create`. Мы его расширяем (не заменяем), чтобы
 * добавить один канал: плитка в шторке (QuickConnectTileService) не может
 * напрямую вызвать Dart-код, пока движок Flutter не запущен — поэтому она
 * просто открывает это Activity с флагом EXTRA_QUICK_CONNECT, а мы отдаём
 * этот флаг в Dart через MethodChannel, как только он его спросит.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_QUICK_CONNECT = "quick_connect"
        const val CHANNEL = "com.gradelvpn/quick_connect"

        // Ставится, когда плитку нажали до того, как Flutter успел
        // спросить (например, приложение было полностью закрыто и только
        // разворачивается) — и забирается один раз.
        @Volatile
        private var pendingQuickConnect: Boolean = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        consumeIntent(intent)
    }

    private fun consumeIntent(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_QUICK_CONNECT, false) == true) {
            pendingQuickConnect = true
            intent.removeExtra(EXTRA_QUICK_CONNECT)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "takePendingQuickConnect" -> {
                        val value = pendingQuickConnect
                        pendingQuickConnect = false
                        result.success(value)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
