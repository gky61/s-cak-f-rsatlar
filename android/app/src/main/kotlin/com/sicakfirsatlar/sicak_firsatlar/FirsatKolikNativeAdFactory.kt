package com.sicakfirsatlar.sicak_firsatlar

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * FırsatKolik Android Native Reklam Fabrikası (Enterprise NativeAdFactory).
 *
 * Google'ın varsayılan Native Templates (small) şablonundaki yapısal kısıtları (MediaView olmaması sebebiyle
 * video/ana medya geldiğinde çıkan "MediaView not used for main image or video asset" hatası) kökten çözer.
 * 
 * Hem video hem görsel reklamları kurumsal standartta MediaView ve fallback ImageView ile render eder.
 */
class FirsatKolikNativeAdFactory(private val context: Context) : GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val inflater = LayoutInflater.from(context)
        val adView = inflater.inflate(R.layout.firsatkolik_native_ad, null) as NativeAdView

        val isDark = (customOptions?.get("isDark") as? Boolean) ?: false

        // Tema Renkleri
        val surfaceColor = if (isDark) Color.parseColor("#1C1C1E") else Color.parseColor("#F1F5F9")
        val borderColor = if (isDark) Color.parseColor("#3A3A3C") else Color.parseColor("#CBD5E1")
        val primaryTextColor = if (isDark) Color.WHITE else Color.parseColor("#141C29")
        val secondaryTextColor = if (isDark) Color.parseColor("#9999A1") else Color.parseColor("#63738C")
        val brandOrange = Color.parseColor("#FF6B00")

        val container = adView.findViewById<LinearLayout>(R.id.ad_container)
        val bgDrawable = GradientDrawable().apply {
            setColor(surfaceColor)
            setStroke(2, borderColor)
            cornerRadius = 32f // 16dp
        }
        container.background = bgDrawable

        // 1. MediaView ve IconView
        val mediaContainer = adView.findViewById<FrameLayout>(R.id.media_container)
        val mediaBg = GradientDrawable().apply {
            setColor(if (isDark) Color.parseColor("#29292E") else Color.WHITE)
            setStroke(2, borderColor)
            cornerRadius = 24f // 12dp
        }
        mediaContainer.background = mediaBg
        mediaContainer.clipToOutline = true

        val mediaView = adView.findViewById<MediaView>(R.id.ad_media)
        val iconView = adView.findViewById<ImageView>(R.id.ad_icon)

        // MediaView kaydı: Bu satır Google AdMob Validator uyarısını ve video oynatma sorunlarını %100 çözer!
        adView.mediaView = mediaView

        val mediaContent = nativeAd.mediaContent
        val hasMedia = mediaContent != null && (mediaContent.hasVideoContent() || nativeAd.images.isNotEmpty())

        if (hasMedia) {
            mediaView.visibility = View.VISIBLE
            iconView.visibility = View.GONE
        } else {
            val icon = nativeAd.icon
            if (icon != null && icon.drawable != null) {
                iconView.setImageDrawable(icon.drawable)
                iconView.visibility = View.VISIBLE
                mediaView.visibility = View.GONE
                adView.iconView = iconView
            } else {
                mediaView.visibility = View.VISIBLE
                iconView.visibility = View.GONE
            }
        }

        // 2. Başlık
        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        headlineView.text = nativeAd.headline
        headlineView.setTextColor(primaryTextColor)
        adView.headlineView = headlineView

        // 3. Reklam Rozeti
        val badgeView = adView.findViewById<TextView>(R.id.ad_badge)
        val badgeBorder = GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            setStroke(2, Color.parseColor("#3A6629"))
            cornerRadius = 6f
        }
        badgeView.background = badgeBorder

        // 4. Reklamveren / Mağaza ve Yıldız Puanı
        val advertiserView = adView.findViewById<TextView>(R.id.ad_advertiser)
        val store = nativeAd.store
        val advertiser = nativeAd.advertiser
        var advertiserText = advertiser ?: (store ?: "")
        val starRating = nativeAd.starRating
        if (starRating != null && starRating > 0) {
            val stars = "★".repeat(Math.min(5, starRating.toInt()))
            advertiserText = if (advertiserText.isEmpty()) stars else "$advertiserText • $stars"
        }
        advertiserView.text = advertiserText
        advertiserView.setTextColor(secondaryTextColor)
        adView.advertiserView = advertiserView

        // 5. CTA Butonu
        val ctaView = adView.findViewById<Button>(R.id.ad_call_to_action)
        ctaView.text = nativeAd.callToAction ?: "Fırsatı Gör"
        ctaView.setBackgroundColor(brandOrange)
        ctaView.setTextColor(Color.WHITE)
        adView.callToActionView = ctaView

        // Native reklam varlıklarını NativeAdView bileşenine bağla
        adView.setNativeAd(nativeAd)

        return adView
    }
}
