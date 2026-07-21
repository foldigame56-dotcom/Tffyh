package com.gradelvpn.gradelvpn

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

/**
 * Плитка "GradelVPN" в шторке (см. первый скриншот в чате — потянуть
 * шторку вниз до конца и нажать карандаш "Изменить", чтобы вытащить её
 * туда). По нажатию: открывает приложение с пометкой quick_connect=true,
 * оно само пингует все сервера и подключается к самому быстрому — та же
 * логика, что и кнопка "автовыбор" на главном экране.
 *
 * Важно понимать ограничение: Android quick-settings tile не может сам
 * поднять VPN-туннель в обход приложения — само V2Ray-ядро живёт внутри
 * Flutter-процесса. Поэтому нажатие на плитку на мгновение открывает
 * приложение (как в большинстве VPN-клиентов с похожей плиткой), а не
 * подключается полностью "по-тихому" без открытия интерфейса.
 */
class QuickConnectTileService : TileService() {

    override fun onClick() {
        super.onClick()
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            putExtra(MainActivity.EXTRA_QUICK_CONNECT, true)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // Android 14+: сворачивает шторку сама и красиво анимирует переход.
            startActivityAndCollapse(
                android.app.PendingIntent.getActivity(
                    this,
                    0,
                    intent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or
                        android.app.PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
        } else {
            @Suppress("DEPRECATION")
            startActivityAndCollapse(intent)
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        qsTile?.state = Tile.STATE_INACTIVE
        qsTile?.label = "GradelVPN: лучший сервер"
        qsTile?.updateTile()
    }
}
