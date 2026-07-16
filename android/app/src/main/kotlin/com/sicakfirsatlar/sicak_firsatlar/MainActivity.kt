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

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        io.flutter.plugin.common.MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sicakfirsatlar.app/native_http").setMethodCallHandler { call, result ->
            if (call.method == "fetchUrl") {
                val urlString = call.argument<String>("url")
                val userAgent = call.argument<String>("userAgent")
                val cookie = call.argument<String>("cookie")
                if (urlString == null) {
                    result.error("BAD_ARGS", "Missing url", null)
                    return@setMethodCallHandler
                }
                
                Thread {
                    try {
                        val url = java.net.URL(urlString)
                        val connection = url.openConnection() as java.net.HttpURLConnection
                        connection.requestMethod = "GET"
                        connection.setRequestProperty("User-Agent", userAgent ?: "WhatsApp/2.23.4.15 A")
                        connection.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8")
                        connection.setRequestProperty("Accept-Language", "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7")
                        if (cookie != null) {
                            connection.setRequestProperty("Cookie", cookie)
                        }
                        connection.connectTimeout = 10000
                        connection.readTimeout = 10000
                        
                        val responseCode = connection.responseCode
                        if (responseCode == java.net.HttpURLConnection.HTTP_OK) {
                            val reader = java.io.BufferedReader(java.io.InputStreamReader(connection.inputStream))
                            val response = StringBuilder()
                            var line: String?
                            while (reader.readLine().also { line = it } != null) {
                                response.append(line).append("\n")
                            }
                            reader.close()
                            val html = response.toString()
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.success(html)
                            }
                        } else {
                            android.os.Handler(android.os.Looper.getMainLooper()).post {
                                result.error("HTTP_ERROR", "Status code: $responseCode", null)
                            }
                        }
                        connection.disconnect()
                    } catch (e: Exception) {
                        android.os.Handler(android.os.Looper.getMainLooper()).post {
                            result.error("ERROR", e.message, null)
                        }
                    }
                }.start()
            } else {
                result.notImplemented()
            }
        }
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

