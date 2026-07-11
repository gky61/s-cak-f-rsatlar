# FırsatKolik Bildirim Sistemi — Tek Cihaz Test Senaryoları

Bu rehber, elinizde **tek bir mobil cihaz** ve **Web Admin Paneli** varken tüm bildirim akışlarını (akıllı birleştirme, çıkışta sızıntıyı önleme, hız limitleri, sessiz saatler) adım adım nasıl test edeceğinizi açıklar.

---

## 👥 Test Rolleri ve Hazırlık
*   **Mobil Cihaz (Hesap A - Alıcı)**: Uygulamada giriş yapmış, bildirimleri alacak ana test hesabınız. (Örn: `alici@gmail.com`)
*   **Web Admin Paneli (Hesap B - Paylaşan / Yönetici)**: Masaüstü tarayıcısından fırsat ekleyen ve onaylayan yönetici hesabınız.

---

## 📋 Senaryo 1: Akıllı Birleştirme ve Öncelik Testi (Deduplication)
**Amaç**: Bir fırsat birden fazla kritere (kelime, yazar, kategori) uysa bile sadece 1 adet en yüksek öncelikli (`keyword`) bildirimin geldiğini doğrulamak.

1.  **Telefonda (Hesap A ile)**:
    *   Uygulamaya giriş yapın.
    *   Ayarlar -> Bildirim Ayarları ekranından **Elektronik** kategorisini takibe alın.
    *   Anahtar kelime takip listesine **"Dyson"** kelimesini ekleyin.
    *   Diğer bir kullanıcının (Örn: **Hesap B - Yazar**) profil sayfasına gidin ve profilindeki **Bildirim Zilini (🔔)** açın.
    *   Uygulamayı arka plana alın (kapatmayın).
2.  **Web Admin Panelinde**:
    *   Yeni bir fırsat oluşturun:
        *   **Başlık**: "Dyson V15 Süper Fiyat"
        *   **Kategori**: Elektronik
        *   **Paylaşan (Yazar)**: Hesap B (Zilini açtığınız yazarın UID'si veya ismi)
        *   **Durum**: `published` (Yayında) yapın.
3.  **Doğrulama**:
    *   Telefona **sadece 1 adet** push bildirimi ulaştığını kontrol edin.
    *   Bildirim içeriğinde anahtar kelimenin ("Dyson") vurgulandığını görün.
    *   Firestore'da `users/{Hesap_A_UID}/notifications` koleksiyonuna gidin ve üretilen belgeyi inceleyin:
        *   `reason` alanının **`keyword`** olduğunu (en yüksek öncelik) doğrulayın.
        *   `reasons` haritasında hem `keyword: "dyson"`, hem `category: "Elektronik"`, hem de `author: "Yazar_UID"` değerlerinin doğru şekilde birleştirildiğini kontrol edin.

---

## 📋 Senaryo 2: Oturum Kapatma ve Sızıntı Önleme Testi
**Amaç**: Bir hesaptan çıkış yapıldığında cihaz token'ının pasifleştirildiğini ve yeni giriş yapan hesaba eski hesabın bildirimlerinin sızmadığını doğrulamak.

1.  **Telefonda (Hesap A ile)**:
    *   "Dyson" kelimesi ve "Elektronik" takipleri aktifken profil ekranına gidin.
    *   **Çıkış Yap** butonuna basın.
2.  **Firestore Konsolunda Kontrol**:
    *   `userDevices` koleksiyonuna gidin.
    *   Hesap A'ya ait `{HesapA_UID}_{CihazID}` belgesinde **`active` alanının `false` olduğunu** doğrulayın.
3.  **Telefonda (Yeni Hesap C ile)**:
    *   Farklı bir e-posta ile (Hesap C) giriş yapın. Bu hesabın bildirim ayarlarında kelime veya kategori takibi **olmasın**.
    *   Uygulamayı arka plana atın.
4.  **Web Admin Panelinde**:
    *   Başlığında "Dyson" geçen ve kategorisi "Elektronik" olan yeni bir fırsat yayınlayın.
5.  **Doğrulama**:
    *   Telefona **hiçbir bildirim gelmediğini** doğrulayın (Sızıntı engellenmiştir).
    *   Firestore'da Hesap A'ya ait bildirim belgesinde `pushStatus: "failed"` yazmalıdır (aktif cihaz bulunamadığı için).

---

## 📋 Senaryo 3: Kategori Hız Limitleri (Rate Limiting) Testi
**Amaç**: Admin panelinden belirlenen kategori bildirim hız sınırlarına sistemin tam olarak uyduğunu doğrulamak.

1.  **Telefonda (Hesap A ile)**:
    *   Giriş yapın ve **Elektronik** kategorisini takibe alın (Kelime takibiniz olmasın).
    *   Uygulamayı arka plana atın.
2.  **Web Admin Panelinde**:
    *   Ayarlar -> "Bot ve Uygulama Yapılandırması" bölümüne gidin.
    *   **Kategori Saatlik Bildirim Limiti** değerini **`1`** olarak ayarlayıp kaydedin.
3.  **Web Admin / Firestore Üzerinden**:
    *   Aralarında 10 saniye olacak şekilde **Elektronik** kategorisinde sırayla **2 adet farklı fırsat** yayınlayın.
4.  **Doğrulama**:
    *   Telefona **sadece 1 adet** push bildirimi ulaştığını doğrulayın.
    *   İkinci bildirim için Firestore'daki ilgili belgede (`users/{uid}/notifications/{id}`):
        *   `pushStatus` değerinin **`failed`** olduğunu,
        *   `error` değerinin **`hourly_limit_exceeded`** (veya `daily_limit_exceeded`) olduğunu doğrulayın.
        *   Ancak uygulamanın içindeki **Bildirim Merkezi** sayfasına girdiğinizde iki bildirimi de listede görebildiğinizi doğrulayın (Uygulama içi kayıtlar sınırlandırılmaz, sadece push engellenir).

---

## 📋 Senaryo 4: Sessiz Saatler (Quiet Hours) Testi
**Amaç**: Sessiz saatler aktifken push bildirimlerinin engellendiğini fakat Bildirim Merkezinde görünmeye devam ettiğini doğrulamak.

1.  **Telefonda (Hesap A ile)**:
    *   Ayarlar -> Bildirim Ayarları ekranına gidin.
    *   **Sessiz Saatler** seçeneğini aktif hale getirin.
    *   Sessiz saatlerin başlangıç ve bitişini **şu anki saatinizi kapsayacak** şekilde ayarlayın (Örn: Saat 14:15 ise başlangıç: 14:00, bitiş: 15:00 yapın).
    *   Uygulamayı arka plana atın.
2.  **Web Admin Panelinde**:
    *   Takip ettiğiniz bir kelimeyle (Örn: "Dyson") eşleşen yeni bir fırsat yayınlayın.
3.  **Doğrulama**:
    *   Telefona **ses tonu veya titreşim dahil hiçbir push bildirimi gelmediğini** doğrulayın.
    *   Uygulamayı açıp Bildirim Merkezine (Zil simgesine) girdiğinizde, fırsat bildiriminin **orada listelendiğini** doğrulayın.
    *   Firestore belgesinde `pushStatus: "failed"` ve `error: "quiet_hours_active"` yazdığını doğrulayın.
