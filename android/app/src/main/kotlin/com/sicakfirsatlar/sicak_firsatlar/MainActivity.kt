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
                if (urlString == null) {
                    result.error("BAD_ARGS", "Missing url", null)
                    return@setMethodCallHandler
                }
                
                if (urlString.contains("getir.com") || urlString.contains("zara.com")) {
                    android.os.Handler(android.os.Looper.getMainLooper()).post {
                        var hasResponded = false
                        try {
                            val webView = android.webkit.WebView(this)
                            webView.settings.javaScriptEnabled = true
                            webView.settings.domStorageEnabled = true
                            if (userAgent != null) {
                                webView.settings.userAgentString = userAgent
                            }
                            
                            val timeoutRunnable = Runnable {
                                if (!hasResponded) {
                                    hasResponded = true
                                    webView.evaluateJavascript("document.documentElement.outerHTML") { htmlResult ->
                                        var html = htmlResult ?: ""
                                        if (html.startsWith("\"") && html.endsWith("\"") && html.length > 1) {
                                            try {
                                                html = org.json.JSONTokener(html).nextValue() as String
                                            } catch (e: Exception) {}
                                        }
                                        result.success(html)
                                        webView.destroy()
                                    }
                                }
                            }
                            val handler = android.os.Handler(android.os.Looper.getMainLooper())
                            handler.postDelayed(timeoutRunnable, 12000)
                            
                            webView.webViewClient = object : android.webkit.WebViewClient() {
                                override fun onPageFinished(view: android.webkit.WebView?, url: String?) {
                                    handler.removeCallbacks(timeoutRunnable)
                                    if (!hasResponded) {
                                        hasResponded = true
                                        webView.evaluateJavascript("document.documentElement.outerHTML") { htmlResult ->
                                            var html = htmlResult ?: ""
                                            if (html.startsWith("\"") && html.endsWith("\"") && html.length > 1) {
                                                try {
                                                    html = org.json.JSONTokener(html).nextValue() as String
                                                } catch (e: Exception) {}
                                            }
                                            result.success(html)
                                            webView.destroy()
                                        }
                                    }
                                }
                                
                                override fun onReceivedError(
                                    view: android.webkit.WebView?,
                                    request: android.webkit.WebResourceRequest?,
                                    error: android.webkit.WebResourceError?
                                ) {
                                    if (request?.isForMainFrame == true) {
                                        handler.removeCallbacks(timeoutRunnable)
                                        if (!hasResponded) {
                                            hasResponded = true
                                            result.error("WEBVIEW_ERROR", error?.description?.toString() ?: "Unknown error", null)
                                            webView.destroy()
                                        }
                                    }
                                }
                            }
                            webView.loadUrl(urlString)
                        } catch (e: Exception) {
                            if (!hasResponded) {
                                hasResponded = true
                                result.error("ERROR", e.message, null)
                            }
                        }
                    }
                } else {
                    Thread {
                        try {
                            val url = java.net.URL(urlString)
                            val connection = url.openConnection() as java.net.HttpURLConnection
                            connection.requestMethod = "GET"
                            connection.setRequestProperty("User-Agent", userAgent ?: "WhatsApp/2.23.4.15 A")
                            connection.setRequestProperty("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8")
                            connection.setRequestProperty("Accept-Language", "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7")
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
                }
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

