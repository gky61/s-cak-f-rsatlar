**FırsatKolik Uygulaması Yeni Geliştirmeler Listesi**
Aşağıda uygulamaya eklenecek yeni özellikler, mantık güncellemeleri ve çözülmesi gereken hatalar yer almaktadır:

**1. Mesajlaşma Ekranından Profil Sayfasına Geçiş (Yeni Özellik)**
 * **Amaç:** Mesajlar (Chat) ekranında, kullanıcıların birbirlerinin profillerini kolayca ziyaret edebilmesi.
 * **İstenen Aksiyon:** Mesajlaşma arayüzünde görünen "gönderici ismi" ve "profil görseli" bileşenlerine InkWell veya GestureDetector eklenmeli. Bu alanlara tıklandığında, ilgili kullanıcının userId bilgisiyle birlikte profil sayfasına navigasyon (yönlendirme) yapılmalı.

**2. Hesap Silme İşleminde Yetki Hatası (Hata Giderme)**
 * **ALINAN NET HATA METNİ:**
## Hesap silinirken bir hata oluştu: [cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation.
 * **Sorun:** Kullanıcı uygulama içerisinden hesabını silmek istediğinde yukarıdaki hatayı alıyor ve silme işlemi yarıda kalıyor.
 * **İstenen Aksiyon:** * Firebase Firestore Güvenlik Kuralları (Security Rules) incelenmeli; kullanıcıların kendi verilerini içeren koleksiyonlarda (özellikle kullanıcı dokümanlarında) delete (silme) izninin (request.auth.uid == userId) eksik olup olmadığı kontrol edilmeli.
   * Flutter tarafındaki kodun çalışma sırası (execution order) kontrol edilmeli. İşlem sırası "Önce Firestore verilerini sil, en son Auth hesabını sil" şeklinde olmalıdır.

**3. Gelişmiş Bildirim Ayarları ve Bağımsız Kontrol (Yeni Özellik / Mantık Güncellemesi)**
 * **Amaç:** Kullanıcıların bildirimleri daha esnek bir şekilde yönetebilmesi, genel bildirimleri kapatsalar bile kritik takipleri almaya devam edebilmesi.
 * **İstenen Aksiyon:**
   * Bildirimler sekmesine **"Kategori Bildirimleri"** ve **"Anahtar Kelime Takibi Bildirimleri"** için ayrı, bağımsız kontrol butonları (Switch/Toggle) eklenmeli.
   * **Mantık Kuralları:** Uygulamada genel veya "Tüm Bildirimler" seçeneği kapatıldığında normal şartlarda bildirim akışı kesilmeli; ancak "Kategori" ve "Anahtar Kelime Takibi" bildirim butonları bu genel durumdan bağımsız çalışabilmeli. Kullanıcı genel bildirimleri kapatmış olsa bile, bu iki özel butondan istediklerini açabilmeli ve ilgili bildirimleri almaya devam edebilmeli.

**4. Fırsatların 2 Gün Sonra Tamamen Kaldırılması (Zaman Aşımı / Mantık Güncellemesi)**
 * **Amaç:** Uygulamanın her zaman dinamik ve güncel kalması için, paylaşılan fırsatların ömür boyu listede kalmasının engellenmesi.
 * **İstenen Aksiyon:**
   * Hem **Ana Ekrandaki** (akıştaki) fırsatlar hem de kullanıcının **"Beğendiklerim"** bölümünde yer alan fırsatlar, paylaşıldığı tarihten itibaren **2. günün sonunda (48 saat dolduğunda) tamamen kalkmalı** ve görünmez olmalıdır.
   * **Teknik Detay:** Veri tabanı sorgularına (Firebase Queries) gönderinin oluşturulma zamanı baz alınarak Oluşturulma Tarihi >= Son 48 Saat filtresi eklenmeli ya da süresi dolan gönderileri iki taraftan da otomatik gizleyecek/temizleyecek bir mantık kurulmalıdır.

**5. Profil Ekranında "Paylaştığı Fırsatları Gör" Butonunun Dinamik Gösterimi (Arayüz / Mantık Güncellemesi)**
 * **Amaç:** Butonun sadece ihtiyaç duyulan yerde (kullanıcının kendi profilinde) görünür olması, diğer kullanıcıların profilleri ziyaret edildiğinde arayüzde kalabalık yapmaması.
 * **İstenen Aksiyon:** * Arayüzdeki "Paylaştığım Fırsatları Gör" butonuna dinamik bir görünürlük (visibility) kuralı eklenmeli.
   * Kullanıcı **kendi profiline** girdiğinde bu buton görünmeye devam etmeli ve tıklandığında son paylaştığı 5 fırsatı görebilmeli.
   * Kullanıcı **başka bir kişinin profiline** girdiğinde ise bu butona gerek olmadığı için arayüzden (UI) tamamen gizlenmeli (Bu profillerde son 5 paylaşım doğrudan listelenecektir).

**6. Yorumlarda "Cevap Ver" Butonunun Kaldırılması ve Sağa Çekerek Yanıtlama (UX / Yeni Özellik)**
 * **Amaç:** Yorumlar bölümündeki klasik "Cevap Ver" butonunu kaldırarak, modern mesajlaşma uygulamalarındaki gibi daha pratik bir "kaydırarak alıntılama" mekanizması kurmak.
 * **İstenen Aksiyon:**
   * Yorumlar alanındaki mevcut sabit "Cevap Ver" seçeneği/butonu arayüzden tamamen kaldırılmalı.
   * Her bir yorum satırı (comment card/widget) **sağa doğru kaydırılabilir** (swipeable) hale getirilmeli.
   * Kullanıcı ilgili yorumu sağa çektiğinde, o yorumu otomatik olarak "alıntılayarak" cevap verme modu açılmalı; yorum yazma alanının hemen üstünde alıntılanan mesaj görünmeli ve kullanıcı bu şekilde yanıt verebilmelidir.

**7. Dışa Paylaşımlarda Uygulamaya Geri Yönlendiren Link (Deep Link) Eklenmesi (Büyüme / Kullanıcı Kazanımı)**
 * **Sorun/Amaç:** FırsatKolik uygulamasındaki bir fırsat "Paylaş" butonuyla WhatsApp, Telegram gibi dış platformlara gönderildiğinde, mesajın sonundaki "📱 FIRSATKOLİK ile keşfet!" kısmı sadece düz metin olarak gidiyor. Bu durum, paylaşımı gören yeni kişilerin FırsatKolik uygulamasına kolayca ulaşmasını engelliyor.
 * **İstenen Aksiyon:**
   * Dışa aktarılan paylaşım metninin sonuna, kullanıcıları doğrudan uygulamaya (veya uygulama yüklü değilse uygulama mağazasına) yönlendirecek dinamik bir bağlantı (**Firebase Dynamic Links**, **App Links** veya standart bir indirme linki) eklenmeli.
   * Metin şablonu şu şekilde güncellenmeli:
     📱 FIRSATKOLİK ile keşfet: [Buraya Uygulama veya Fırsat Linki Gelecek]
     *(Örn: https://firsatkolik.app.link/indirme)*