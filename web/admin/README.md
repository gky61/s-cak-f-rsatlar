# 💻 FırsatKolik Web Admin Paneli

FırsatKolik platformunun tarayıcı üzerinden yönetilebilen, 10 modülden oluşan resmi web yönetim merkezidir.

---

## 📍 Barındırma ve Adresler
Firebase Hosting üzerinde barındırılır ve `config.js` aracılığıyla tarayıcının hostname değerine göre ilgili Firebase projesine (`sicak-firsatlar-e6eae` vs `firsatkolik-prod-e6eae`) dinamik olarak bağlanır:

* **DEV Admin Paneli:** `https://sicak-firsatlar-e6eae.web.app/admin/` (veya yerel testte `http://localhost:5000/admin/`)
* **PROD Admin Paneli:** `https://firsatkolik-prod-e6eae.web.app/admin/`

---

## 🚀 Dağıtım (Deploy)

```bash
# DEV Hosting'e Dağıt
firebase use dev
firebase deploy --only hosting

# PROD (Canlı) Hosting'e Dağıt
firebase use prod
firebase deploy --only hosting
```

---

## ✨ 10 Temel Yönetim Modülü

1. 📊 **Dashboard Görünümü:** Canlı sistem sağlığı (Bot Heartbeat), genel istatistikler ve haftalık trend grafikleri.
2. 🏷️ **Fırsatlar Görünümü:** Onay bekleyen fırsatları onaylama/reddetme, düzenleme modalı, resim lightbox ve affiliate link dönüştürme.
3. 👥 **Kullanıcılar Görünümü:** Profil inceleme, özel admin mesajı gönderme ve `adminDeleteUser` ile kullanıcı silme.
4. 💬 **Mesajlar & Simülatör:** İki kullanıcı arası canlı mesajlaşma simülatörü, gerçek zamanlı sohbet akışı ve Botkolik AI sohbetleri.
5. 🚩 **Şikayetler & Raporlar:** Kullanıcıların ilettiği içerik şikayet havuzu, tek tıkla silme ve ban uygulama.
6. ⚙️ **Sistem & Bot Ayarları:** Dinamik Telegram kanalları yönetimi (`monitoredChannels`), bot durdurma/başlatma, fırsat/yorum/kupon şalterleri ve 30+ günlük eski veri temizliği (`purgeOldDealsWeb`).
7. 🔔 **Bildirimler Merkezi:** Cihaz izin istatistikleri, saatlik/günlük hız limitleri, manuel push gönderme ve geçersiz token temizliği.
8. 📜 **Sistem Logları:** Firestore `systemErrors` koleksiyonundaki sunucu/bot hata kayıtları ve filtreleme.
9. 🎟️ **Kuponlar Yönetimi:** Kupon ekleme/düzenleme/silme ve Cloud Functions ile çok kaynaklı otomatik kupon kazıma.
10. 📰 **Aktüel Kataloglar:** Süpermarket broşürlerini inceleme/silme ve Cloud Functions ile otomatik aktüel kazıma.

---

## 📚 Detaylı Mimari Dokümantasyonu
Panelin kaynak kod fonksiyonları, yetki denetimi ve operasyonel yönergeler için:
👉 [Web Admin Paneli Kapsamlı Mimari ve Operasyon Rehberi](file:///d:/firsatkolik/documentation/mimari-ve-sistem/web_admin_paneli_rehberi.md)
