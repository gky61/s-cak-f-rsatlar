# 💻 FırsatKolik Web Admin Paneli

FırsatKolik platformunun tarayıcı üzerinden yönetilebilen, 10 modülden oluşan resmi web yönetim merkezidir.

---

# 💻 FırsatKolik Web Admin Paneli

FırsatKolik platformunun tarayıcı üzerinden yönetilebilen, 10 modülden oluşan, harici derleme gerektirmeyen (Vanilla JS/CSS/HTML5 SPA) resmi web yönetim merkezidir.

---

## 📍 1. Barındırma ve Sıfır Sızıntı Ortam İzolasyonu (Zero-Leakage Architecture)

Web Admin Paneli, tek bir kaynak kod tabanından (`web/admin/`) çalışır ve **`config.js`** aracılığıyla tarayıcının çalıştığı web adresine (hostname) göre ilgili Firebase projesine (`sicak-firsatlar-e6eae` vs `firsatkolik-prod-e6eae`) **çalışma anında (runtime)** dinamik olarak bağlanır.

### 🌐 Hostname Eşleme Matrisi

| Çalışılan Adres / Hostname | Bağlanılan Firebase Projesi | Ortam Türü | Açıklama |
|---|---|---|---|
| `localhost` / `127.0.0.1` | `sicak-firsatlar-e6eae` *(Varsayılan)* veya `firsatkolik-prod-e6eae` | ⚙️ DEV / 🚀 PROD Seçilebilir | Yerel test ortamı. Üst menüdeki açılır liste ile anlık ortam değiştirilebilir. |
| `sicak-firsatlar-e6eae.web.app` | `sicak-firsatlar-e6eae` | ⚙️ DEV (Geliştirme / Test) | DEV test veritabanı, test bildirimleri ve test botu. |
| `sicak-firsatlar-e6eae.firebaseapp.com` | `sicak-firsatlar-e6eae` | ⚙️ DEV (Alternatif URL) | DEV test ortamı. |
| `firsatkolik-prod-e6eae.web.app` | `firsatkolik-prod-e6eae` | 🚀 PROD (Canlı / Üretim) | Canlı kullanıcılar, gerçek fırsatlar ve canlı push bildirimleri. |
| `firsatkolik-prod-e6eae.firebaseapp.com` | `firsatkolik-prod-e6eae` | 🚀 PROD (Alternatif URL) | Canlı sistem. |
| `firsatkolik.app` / `admin.firsatkolik.app` | `firsatkolik-prod-e6eae` | 🚀 PROD (Özel Alan Adı) | Özel alan adı üzerinden doğrudan canlı Firebase projesine kilitlenir. |

### 🔄 Yerel Testte Ortam Değiştirici (`#envSwitcher`)
`localhost` üzerinde çalışırken sol üst navigasyon rozeti (`#envBadge`) otomatik olarak etkileşimli bir `<select>` kutusuna dönüşür:
* **DEV ⚙️ (`sicak-firsatlar-e6eae`)**: Test verileri üzerinde güvenle geliştirme yapmanızı sağlar.
* **PROD 🚀 (`firsatkolik-prod-e6eae`)**: Canlı ortamdaki verileri yerel makinenizden güvenli şekilde incelemenize olanak tanır.
* Seçim `localStorage.getItem('firebase_env')` anahtarına yazılır ve sayfa yeniden yüklendiğinde hafızada korunur.

### 🛡️ 10 Modülde Veri İzolasyon Güvencesi
Tüm modüller (`app.js`), `config.js` tarafından o an aktif edilen tek bir `firebase.firestore()` (`db`), `firebase.auth()` (`auth`) ve `firebase.storage()` örneği üzerinden çalışır. Paneldeki **hiçbir modülde statik/hardcoded proje ID sorgusu bulunmaz**. Böylece DEV ortamındayken yapılan bir silme, onaylama veya bildirim işlemi **asla** PROD ortamına sızamaz.

---

## 🚀 2. Dağıtım (Deploy) Yönergeleri

```bash
# DEV Hosting Ortamına Dağıtım (https://sicak-firsatlar-e6eae.web.app/admin/)
firebase use dev
firebase deploy --only hosting

# PROD Canlı Hosting Ortamına Dağıtım (https://firsatkolik-prod-e6eae.web.app/admin/)
firebase use prod
firebase deploy --only hosting
```

---

## ✨ 3. 10 Temel Yönetim Modülü

1. 📊 **Dashboard Görünümü:** Canlı sistem sağlığı (Telegram Bot Heartbeat, Gemini AI maliyet ve hız limitleri), 6 sütunlu Bento metrikleri, 7 günlük trend grafikleri ve onay bekleyen hızlı işlem kuyruğu.
2. 🏷️ **Fırsatlar Görünümü:** Onay bekleyen fırsatları onaylama/reddetme, fiyat & indirim oranı düzeltme modalı, resim lightbox önizleme ve affiliate link dönüştürücü.
3. 👥 **Kullanıcılar Görünümü:** Üye profilleri, avcı rozetleri, ban durumu, özel admin mesajı gönderme ve `adminDeleteUser` ile kullanıcıyı Auth + Firestore'dan kalıcı silme.
4. 💬 **Mesajlar & Simülatör:** İki kullanıcı arası canlı mesajlaşma simülatörü, gerçek zamanlı sohbet akışı ve Botkolik AI sohbetleri.
5. 🚩 **Şikayetler & Raporlar:** Kullanıcıların ilettiği içerik şikayet havuzu, tek tıkla ilanı silme, şikayeti kapatma ve kullanıcıyı yasaklama.
6. ⚙️ **Sistem & Bot Ayarları:** Dinamik Telegram kanalları yönetimi (`monitoredChannels`), bot durdurma/başlatma, fırsat/yorum/kupon şalterleri ve 30+ günlük eski verileri temizleme (`purgeOldDealsWeb`).
7. 🔔 **Bildirimler Merkezi:** Kayıtlı ve aktif FCM cihaz istatistikleri, Android/iOS dağılımı, saatlik/günlük hız sınırları, manuel push gönderme ve geçersiz token temizliği (`cleanupInvalidTokens`).
8. 📜 **Sistem Logları (Kibana / Datadog APM):** Uçtan uca hata havuzu (`systemErrors`), 8 kategori sekmesi (Mobil, Bot, Kazıyıcı, Katalog, Kupon, AI, Bildirim, Cloud, Web), **kullanıcı adı/UID bazlı arama ve filtreleme**, derin geçmiş taraması (`deepSearchUserLogs`), önem derecesi ve platform filtreleri, stack trace panosu ve tek tıkla çözüldü işaretleme.
9. 🎟️ **Kuponlar Yönetimi:** Topluluk vs Botkolik Radarı sekmeleri, kupon ekleme/düzenleme/silme, tek tıkla kod kopyalama ve Cloud Functions ile çok kaynaklı otomatik kupon kazıma.
10. 📰 **Aktüel Kataloglar:** 36 mağazanın süpermarket broşürlerini inceleme (Lightbox sayfa galerisi), düzenleme/silme ve Cloud Functions ile otomatik aktüel kazıma motoru.

---

## 📚 4. Detaylı Mimari ve Operasyon Dokümantasyonu
Panelin kaynak kod fonksiyonları, yetki denetimi ve operasyonel yönergeler için:
* 👉 [Web Admin Paneli Kapsamlı Mimari ve Operasyon Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/web_admin_paneli_rehberi.md)
* 👉 [Ortam Yönetimi ve Canlıya Geçiş Kılavuzu](file:///d:/firsatkolik/documentation/backend-ve-altyapi/environment_management_guide.md)
* 👉 [Cloud Functions ve Backend Servisleri Rehberi](file:///d:/firsatkolik/documentation/backend-ve-altyapi/cloud_functions_rehberi.md)
