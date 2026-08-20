# 🎨 FırsatKolik Tasarım Sistemi ve Arayüz Standartları Rehberi (Design System)

Bu belge, **Fırsat Paylaşım Ekranı** (`lib/screens/submit_deal_screen.dart`) ve **Uygulama Teması** (`lib/theme/app_theme.dart`) referans alınarak hazırlanmış resmi tasarım rehberidir. Geliştirilecek veya güncellenecek tüm ekranlarda bu tasarım dili, renk çiftleri ve bileşen standartları esas alınacaktır.

---

## 📑 İçindekiler
1. [Genel Tasarım Felsefesi](#1-genel-tasarım-felsefesi)
2. [Renk Paleti ve Aydınlık / Karanlık Mod Eşleşmeleri](#2-renk-paleti-ve-aydınlık--karanlık-mod-eşleşmeleri)
3. [Tipografi ve Hiyerarşi](#3-tipografi-ve-hiyerarşi)
4. [Çekirdek Tasarım Bileşenleri ve Şablon Kodlar](#4-çekirdek-tasarım-bileşenleri-ve-şablon-kodlar)
   - [4.1 Çentikli Kart Kapsayıcısı (Notched / Fieldset Box)](#41-çentikli-kart-kapsayıcısı-notched--fieldset-box)
   - [4.2 Canlı Önizleme Vitrini (Hero Live Preview Card)](#42-canlı-önizleme-vitrini-hero-live-preview-card)
   - [4.3 Form Inputları ve Odak Efektleri](#43-form-inputları-ve-odak-efektleri)
   - [4.4 Minimalist Seçenek ve Switch Satırları](#44-minimalist-seçenek-ve-switch-satırları)
   - [4.5 Yapışkan Alt Aksiyon Barı (Sticky Floating Bar)](#45-yapışkan-alt-aksiyon-barı-sticky-floating-bar)
   - [4.6 Özel Yüzen SnackBar (Floating Feedback Bar)](#46-özel-yüzen-snackbar-floating-feedback-bar)
5. [Mikro Animasyonlar ve Dokunsal Geri Bildirim (Haptics)](#5-mikro-animasyonlar-ve-dokunsal-geri-bildirim-haptics)
6. [Yeni Ekran Geliştirme Kontrol Listesi (Checklist)](#6-yeni-ekran-geliştirme-kontrol-listesi-checklist)

---

## 1. Genel Tasarım Felsefesi

- **Modern & Enerjik:** Ana marka rengi olan sıcak turuncu (`#FF6B35`) ile aksiyonlar canlı tutulur, temiz ve nötr zeminler ile göz yormayan bir denge kurulur.
- **Çentikli / Fieldset Mimarisi:** Formlar ve içerik blokları açıkta bırakılmaz; üst çizgisinde kendi mini rozet başlığını taşıyan modern çentikli kartlar (`Notched Box`) içine alınır.
- **Canlı ve Reaktif Geri Bildirim:** Kullanıcı veri girdikçe ekran canlı önizlemelerle şekillenir; veri bekleme durumlarında iskelet animasyonları (`Shimmer`), durum geçişlerinde yumuşak akışlar (`AnimatedSwitcher` + `Curves.easeOutCubic`) kullanılır.
- **Saf Karanlık Mod Uyum:** Karanlık modda donuk gri zeminler yerine saf siyah (`#000000`) sayfa tabanı ve yüksek kontrastlı koyu kartlar (`#121212` / `#1E1E1E`) kullanılır.

---

## 2. Renk Paleti ve Aydınlık / Karanlık Mod Eşleşmeleri

### 2.1 Temel Katman ve Yüzey Renkleri

| Katman / Eleman | Aydınlık Mod (Light) | Karanlık Mod (Dark) | Flutter Kod Karşılığı |
| :--- | :--- | :--- | :--- |
| **Sayfa Arka Planı** | `#F8FAFC` *(Slate 50)* | `#000000` *(Saf Siyah)* | `isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC)` |
| **Kart Yüzeyi (Surface)** | `#FFFFFF` *(Beyaz)* | `#121212` *(Dark Surface)* | `isDark ? AppTheme.darkSurface : Colors.white` |
| **Yükseltilmiş Yüzey / Input** | `#F1F5F9` *(Slate 100)* | `#1E1E1E` *(Dark Elevated)* | `isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9)` |
| **Sınır / Çerçeve (Border)** | `#E2E8F0` *(Slate 200)* | `#2C2C2C` *(Dark Border)* | `isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)` |
| **Çentik Başlık Sınırı** | `rgba(226,232,240, 0.85)` | `rgba(44,44,44, 0.85)` | `borderColor.withValues(alpha: 0.85)` |
| **Bölücü Çizgi (Divider)** | `#E2E8F0` *(Slate 200)* | `#2A2A2A` / `#2C2C2C` | `isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)` |

### 2.2 Marka, Vurgu ve Metin Renkleri

| Tanım | Aydınlık Mod (Light) | Karanlık Mod (Dark) | Flutter Kod Karşılığı |
| :--- | :--- | :--- | :--- |
| **Birincil Vurgu (Primary)** | `#FF6B35` | `#FF6B35` | `AppTheme.primary` |
| **İkincil Marka (Secondary)**| `#004E92` | `#004E92` | `AppTheme.secondary` |
| **Birincil Metin (Text 1)** | `#0F172A` / `#1E293B` | `#FFFFFF` | `isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A)` |
| **İkincil Metin (Text 2)** | `#64748B` *(Slate 500)* | `#8E8E93` *(Neutral Gray)* | `isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)` |
| **Açık/Pasif Metin (Muted)** | `#94A3B8` *(Slate 400)* | `#71717A` *(Zinc 500)* | `isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8)` |

### 2.3 Durum, Rozet ve Özel Bileşen Renkleri

| Bileşen | Aydınlık Mod (Light) | Karanlık Mod (Dark) | Flutter Kod Değerleri |
| :--- | :--- | :--- | :--- |
| **Botkolik AI Bilgi Kutusu** | Dolgu: `#EFF6FF`<br>Sınır: `#BFDBFE`<br>Metin: `#1E3A8A` | Dolgu: `#1E1E1E`<br>Sınır: `rgba(255,107,53, 0.25)`<br>Metin: `#E4E4E7` | `isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFEFF6FF)` |
| **Uyarı / Bakım Kutusu** | Dolgu: `#FEF3C7`<br>Sınır: `#F59E0B`<br>Metin: `#92400E` | Dolgu: `rgba(69,26,3, 0.60)`<br>Sınır: `#B45309`<br>Metin: `#FDE68A` | `isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)` |
| **Önizleme Rozeti (Hazır)** | Sınır/Yazı: `#16A34A`<br>Dolgu: `#F8FAFC` | Sınır/Yazı: `#16A34A`<br>Dolgu: `#000000` | `const Color(0xFF16A34A)` |
| **Önizleme Rozeti (Tarıyor)** | Sınır/Yazı: `#FF6B35`<br>Dolgu: `#F8FAFC` | Sınır/Yazı: `#FF6B35`<br>Dolgu: `#000000` | `AppTheme.primary` |
| **Kategori Rozeti** | Dolgu: `rgba(255,107,53, 0.08)`<br>Metin: `#FF6B35` | Dolgu: `rgba(255,107,53, 0.18)`<br>Metin: `#FF6B35` | `AppTheme.primary.withValues(alpha: isDark ? 0.18 : 0.08)` |
| **İndirim Oranı Rozeti** | Dolgu: `rgba(220,38,38, 0.12)`<br>Metin: `#DC2626` | Dolgu: `rgba(220,38,38, 0.12)`<br>Metin: `#DC2626` | `const Color(0xFFDC2626)` |
| **Amazon Depo Rozeti** | Dolgu: `rgba(217,119,6, 0.15)`<br>Metin: `#D97706` | Dolgu: `rgba(217,119,6, 0.15)`<br>Metin: `#D97706` | `const Color(0xFFD97706)` |
| **İskelet (Shimmer)** | Temel: `#E2E8F0`<br>Vurgu: `#F1F5F9` | Temel: `#1C1C1C`<br>Vurgu: `#2C2C2C` | `isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE2E8F0)` |

---

## 3. Tipografi ve Hiyerarşi

Tüm tipografide Türkçe karakter desteği tam olan **Roboto** yazı tipi ailesi kullanılır (`GoogleFonts.roboto`).

- **Ekran Başlıkları (App Bar Title):** `18px`, `FontWeight.w800`, `letterSpacing: -0.3`
- **Kart Başlıkları (Notched Title):** `12px`, `FontWeight.w800`, `letterSpacing: -0.2`
- **Ürün / Öğe Başlıkları:** `13px - 14px`, `FontWeight.w800`, `height: 1.25`
- **Fiyat Değerleri:** `15.5px - 17px`, `FontWeight.w900`, `letterSpacing: -0.4`, Rengi: `AppTheme.primary`
- **Girdi Metinleri (Input Fields):** `13.5px`, `FontWeight.w600` veya `w500`
- **Açıklama / İpuçları (Subtitles):** `11.5px - 12.5px`, `FontWeight.w500` / `w400`, `height: 1.35 - 1.45`
- **Rozet Metinleri (Badges):** `10px - 10.5px`, `FontWeight.w700` veya `w800`

---

## 4. Çekirdek Tasarım Bileşenleri ve Şablon Kodlar

### 4.1 Çentikli Kart Kapsayıcısı (Notched / Fieldset Box)
Form alanlarını ve içerik gruplarını sarmalayan temel yapı taşıdır.

```dart
Widget buildNotchedCardContainer({
  required BuildContext context,
  required bool isDark,
  required String title,
  required IconData icon,
  required List<Widget> children,
  Widget? trailing,
}) {
  final bgColor = isDark ? AppTheme.darkSurface : Colors.white;
  final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
  final pageBgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);

  return Stack(
    clipBehavior: Clip.none,
    children: [
      // Ana Çerçeveli Kart
      Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.025),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),

      // Üst Çizgiye Oturan Çentikli Başlık Rozeti
      Positioned(
        top: 0,
        left: 16,
        right: trailing != null ? 16 : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: pageBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: borderColor.withValues(alpha: 0.85),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    ],
  );
}
```

---

### 4.2 Canlı Önizleme Vitrini (Hero Live Preview Card)
Kullanıcının yaptığı işlemlerin anında canlandığı mini vitrin kartı.

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 500),
  reverseDuration: const Duration(milliseconds: 250),
  switchInCurve: Curves.easeOutCubic,
  switchOutCurve: Curves.easeInCubic,
  transitionBuilder: (child, animation) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  },
  child: isLoading
      ? buildPreviewShimmerBody(isDark)
      : buildPreviewLoadedBody(isDark, item),
)
```

---

### 4.3 Form Inputları ve Odak Efektleri
Form alanlarında kullanılan standart dekorasyon yapısı:

```dart
InputDecoration buildStandardInputDecoration({
  required bool isDark,
  required String labelText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    hintStyle: TextStyle(
      color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
      fontSize: 12.5,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? AppTheme.darkBorder : Colors.transparent,
        width: 1,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isDark ? AppTheme.darkBorder : Colors.transparent,
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
  );
}
```

---

### 4.4 Minimalist Seçenek ve Switch Satırları
Hantal checkbox'lar yerine kullanılan hafif dokunsal geçiş satırı:

```dart
Widget buildMinimalToggleRow({
  required bool isDark,
  required IconData icon,
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
  Color? activeColor,
}) {
  final effectiveActiveColor = activeColor ?? AppTheme.primary;
  final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
  final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  return InkWell(
    onTap: () {
      HapticFeedback.selectionClick();
      onChanged(!value);
    },
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: value ? effectiveActiveColor : secondaryTextColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                color: value
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : textColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.78,
            child: Switch(
              value: value,
              activeTrackColor: effectiveActiveColor,
              activeThumbColor: Colors.white,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                onChanged(val);
              },
            ),
          ),
        ],
      ),
    ),
  );
}
```

---

### 4.5 Yapışkan Alt Aksiyon Barı (Sticky Floating Bar)
Sayfa sonuna gömmek yerine ekran altına sabitlenen işlem butonu:

```dart
Widget buildStickySubmitBar({
  required BuildContext context,
  required bool isDark,
  required String label,
  required IconData icon,
  required bool isLoading,
  required VoidCallback? onPressed,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    decoration: BoxDecoration(
      color: isDark
          ? AppTheme.darkSurface.withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95),
      border: Border(
        top: BorderSide(
          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[700],
            elevation: 2,
            shadowColor: AppTheme.primary.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    ),
  );
}
```

---

### 4.6 Özel Yüzen SnackBar (Floating Feedback Bar)

```dart
void showCustomSnackBar({
  required BuildContext context,
  required String message,
  required IconData icon,
  required Color backgroundColor,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      elevation: 6,
      action: action,
    ),
  );
}
```

---

## 5. Mikro Animasyonlar ve Dokunsal Geri Bildirim (Haptics)

Uygulamanın "canlı" hissettirmesi için aşağıdaki mikro etkileşim kuralları uygulanır:

1. **Haptic Feedback (Titreşim):**
   - **Form Gönderme / Ana Aksiyonlar:** `HapticFeedback.mediumImpact()`
   - **Kopyalama / Yapıştırma / Link Tanıma:** `HapticFeedback.lightImpact()`
   - **Switch Değişimi / Kategori Seçimi / Liste Tıklaması:** `HapticFeedback.selectionClick()`

2. **Geçiş Animasyonları (Curves & Transitions):**
   - Tüm durum değişimlerinde `Curves.easeOutCubic` eğrisi kullanılır.
   - Yükleme veya veri değişimlerinde `FadeTransition` + `SlideTransition(begin: Offset(0, 0.04))` kombinasyonu uygulanır.

3. **Görsel Yükleme:**
   - Ağdan gelen görsellerde `fadeInDuration: Duration(milliseconds: 450)` ve `fadeInCurve: Curves.easeOutCubic` kullanılır.

---

## 6. Yeni Ekran Geliştirme Kontrol Listesi (Checklist)

Yeni bir sayfa yazarken veya revize ederken şu maddeleri kontrol edin:

- [ ] **Scaffold Arka Planı:** Aydınlık modda `#F8FAFC`, Karanlık modda `AppTheme.darkBackground` (`#000000`) tanımlı mı?
- [ ] **Kart Yapısı:** `NotchedCardContainer` stili uygulanmış, `18px` köşe yuvarlama ve `1.2px` border kullanılmış mı?
- [ ] **Girdi Alanları:** `filled: true`, Dolgu: `#F1F5F9` / `#1E1E1E`, `focusedBorder`: `#FF6B35` (`1.5px`) yapılmış mı?
- [ ] **Tipografi:** Google Fonts `Roboto`, başlıklar `FontWeight.w800`, fiyatlar `w900` ve turuncu renkte mi?
- [ ] **Alt Buton:** Ekran sonuna gömülü olmak yerine `SafeArea` ve `alpha: 0.95` ile yapışkan (`Sticky`) yapıldı mı?
- [ ] **Dokunsal Geri Bildirim:** Etkileşimli buton ve switch'lere `HapticFeedback` eklendi mi?
- [ ] **Geri Bildirimler:** Standart `SnackBar` yerine `floating`, `14px` radiuslu `showCustomSnackBar` kullanıldı mı?
