# APK Boyut Optimizasyonu — Referans Kılavuzu

## Mevcut Durum

| Metrik | Önce | Sonra |
|---|---|---|
| Fat APK (tüm mimariler) | 72 MB | ~69 MB |
| Tek mimari APK (arm64) | — | **27 MB** |
| Play Store indirme (AAB) | — | **~20-23 MB** |
| Asset boyutu | 3.6 MB | 0.34 MB |

---

## Build Flagları Ne Yapar?

| Komut | Çıktı | Boyut | Açıklama |
|---|---|---|---|
| `flutter build apk --release` | 1 fat APK | ~69 MB | 3 mimariyi (arm64+armv7+x86_64) tek APK'ya paketler. Her cihazda çalışır ama gereksiz büyük. |
| `flutter build apk --release --split-per-abi` | 3 ayrı APK | ~25-28 MB her biri | Her mimari için ayrı APK üretir. Play Store'a hepsini yüklersin, doğru olanı otomatik gönderilir. |
| `flutter build apk --release --target-platform android-arm64` | 1 APK (sadece arm64) | ~27 MB | Sadece belirtilen mimari için tek APK üretir. Kendi cihazında test için en pratik. |
| `flutter build appbundle --release` | 1 AAB dosyası | ~20-23 MB indirme | Google Play'e yüklenir. Play Store her cihaza özel APK üretir. En küçük indirme boyutu. |

> **Eski komut neden 72 MB'dı?** `--split-per-abi` veya `--target-platform` belirtmezsen Flutter varsayılan olarak 3 mimarinin tamamını tek APK'ya dahil eder. Emülatör (x86_64) ve eski telefon (armv7) kütüphaneleri de gereksiz yere paketlenir.

---

## Build Komutları

### Kendi Cihazında Test (DEV)

```bash
# Sadece kendi cihazın için (en hızlı, tek APK ~27 MB)
flutter build apk --release --flavor dev --dart-define=FLAVOR=dev --target-platform android-arm64

# 3 mimari için ayrı APK'lar (arm64 + armv7 + x86_64)
flutter build apk --release --split-per-abi --flavor dev --dart-define=FLAVOR=dev
```

### Google Play Store'a Yükleme (PROD)

```bash
# App Bundle — Play Store'a bu yüklenir (~20-23 MB indirme)
flutter build appbundle --release --flavor prod --dart-define=FLAVOR=prod
```

> **Not:** Google Play 2021'den beri AAB formatını zorunlu kılıyor. Play Console'a `.aab` dosyasını yükle, Google otomatik olarak her cihaza uygun APK üretir.

### Çıktı Dosya Konumları

| Komut | Dosya |
|---|---|
| `--target-platform android-arm64` | `build/app/outputs/flutter-apk/app-dev-release.apk` |
| `--split-per-abi` | `build/app/outputs/flutter-apk/app-arm64-v8a-dev-release.apk` |
| `appbundle` | `build/app/outputs/bundle/prodRelease/app-prod-release.aab` |

---

## Yapılan Optimizasyonlar

### 1. Split-per-ABI (~45 MB kazanç)
Eski fat APK'da 3 farklı CPU mimarisi (arm64, armv7, x86_64) dahildi. Her biri ~20 MB native kütüphane içeriyordu. `--split-per-abi` veya AAB ile sadece kullanıcının cihazına uygun mimari gönderiliyor.

### 2. Asset WebP Dönüşümü (~3.3 MB kazanç)
41 store logosu JPG → WebP formatına dönüştürüldü. Kalite korunarak %91 boyut azalması sağlandı.

### 3. cupertino_icons Kaldırma (~0.1 MB kazanç)
Kodda hiç kullanılmayan `CupertinoIcons` font dosyası (251 KB) APK'dan çıkarıldı.

### 4. Otomatik Optimizasyonlar (Flutter)
- `MaterialIcons-Regular.otf` tree-shaking: 1.6 MB → 23 KB
- R8/ProGuard: Java/Kotlin kodu shrinking + obfuscation aktif
- `shrinkResources: true`: Kullanılmayan Android kaynakları otomatik kaldırılıyor

---

## Mimari Bilgisi

| Mimari | Hedef | Kullanıcı Oranı |
|---|---|---|
| `arm64-v8a` | Modern 64-bit telefonlar | %95+ |
| `armeabi-v7a` | Eski 32-bit telefonlar | %5 |
| `x86_64` | Emülatörler | %0 (dağıtıma dahil edilmez) |
