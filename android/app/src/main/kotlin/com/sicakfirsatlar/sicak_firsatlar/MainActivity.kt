package com.sicakfirsatlar.sicak_firsatlar

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        createNotificationChannelsIfNeeded()
        super.onCreate(savedInstanceState)
    }

    /**
     * FCM bildirimleri uygulama kapalıyken de görünsün diye kanalları uygulama açılmadan oluşturuyoruz.
     * Böylece ilk kurulumda bile admin/mesaj bildirimleri sistem tarafından gösterilebilir.
     */
    private fun createNotificationChannelsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channels = listOf(
            NotificationChannel(
                "admin_channel",
                "Admin Bildirimleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Onay bekleyen fırsatlar"
                setShowBadge(true)
                enableVibration(true)
            },
            NotificationChannel(
                "admin_messages_channel",
                "Admin Mesajları",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Admin mesaj bildirimleri"
                setShowBadge(true)
                enableVibration(true)
            },
            NotificationChannel(
                "messages_channel",
                "Mesajlar",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Sohbet bildirimleri"
                setShowBadge(true)
                enableVibration(true)
            }
        )
        channels.forEach { manager.createNotificationChannel(it) }
    }
}

