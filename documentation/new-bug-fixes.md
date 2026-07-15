**FırsatKolik Uygulaması Geliştirme Listesi (Yeni Seri)**
Aşağıda uygulamaya eklenecek yeni özellikler ve altyapı değişiklikleri yer almaktadır:

**1. Telegram Gruplarından Link Bazlı Veri Çekme ve Yapay Zeka ile Açıklama Optimizasyonu (Altyapı / AI Entegrasyonu)**
 * **Amaç:** Veri toplama sisteminin kaynak mantığını değiştirmek; Telegram'dan doğrudan ham veri çekmek yerine, gruplarda paylaşılan linkleri yakalamak ve bu fırsatların açıklamalarını yapay zeka ile daha anlaşılır hale getirmek.
 * **İstenen Aksiyon:**
   * **Veri Çekme (Scraping) Güncellemesi:** Telegram botunun/sisteminin çalışma mantığı, Telegram gruplarında paylaşılan e-ticaret ve fırsat linklerini tarayacak, tespit edecek ve bu linkler üzerinden veri toplayacak şekilde güncellenmeli.
   * **Yapay Zeka (AI) ile Metin Düzenleme:** Telegram gruplarından linkle birlikte gelen ham, düzensiz veya karmaşık fırsat açıklamaları doğrudan sisteme kaydedilmemeli. Bu metinler arka planda bir Yapay Zeka API'sine gönderilerek; daha net, imla kurallarına uygun, kullanıcı dostu ve akıcı bir fırsat açıklamasına dönüştürüldükten sonra uygulamaya aktarılmalı.

**2. Profil Resmi Güncellemesinin Tüm Uygulamada Eşzamanlı Olması (Veri Senkronizasyonu / Hata Giderme)**
 * **Amaç:** Kullanıcı profil fotoğrafını değiştirdiğinde, eski fotoğrafın uygulama içindeki diğer alanlarda (yorumlar, eski paylaşımlar, mesajlaşma ekranı vb.) kalmaması ve her yerde aynı anda güncellenmesi.
 * **İstenen Aksiyon:**
   * Kullanıcı profil resmini güncellediğinde, yeni görsel URL'sinin veri tabanında kullanıcının ana dokümanına işlenmesi sağlanmalı.
   * Uygulama genelinde (yorum satırları, chat ekranı, gönderi kartları vb.) profil resimleri listelenirken, bu verilerin statik/eski dokümanlardan okunması yerine dinamik olarak güncel kullanıcı verisinden (Stream/Real-time Listener ile) çekilmesi sağlanmalı.
   * Eğer performans amacıyla veriler geçmiş dokümanlara gömülü (denormalized) kaydediliyorsa, profil resmi değiştiğinde kullanıcının eski yorum ve mesajlarındaki eski resim URL'lerini toplu olarak güncelleyecek bir arka plan mekanizması (Batch Write veya Cloud Function) kurgulanmalı.

**3. Profil İçi Bildirim Merkezinin İncelenmesi ve Uygulama İçi (In-App) Bildirim Ayrımı (UX / Mantık Güncellemesi)**
 * **Amaç:** Profildeki bildirimler sekmesinin çalışma mantığının detaylıca analiz edilmesi, mevcut hataların giderilmesi ve cihaz bildirimleri (Push Notification) ile uygulama içi bildirimler arasındaki ayrımın doğru kurgulanması.
 * **İstenen Aksiyon:**
   * Bildirimler sekmesinin arka plan mantığına odaklanılarak, hangi bildirimlerin doğru tetiklendiği ve nelerin çalışmadığı detaylıca test edilmeli.
   * **Sessiz / Uygulama İçi Bildirim Mantığı Kurulmalı:** Her olay için telefona üstten düşen bildirim (Push Notification) gönderilmemeli. Örneğin; kullanıcının paylaştığı bir fırsatın Admin tarafından reddedilmesi veya onaylanması gibi sistemsel geri bildirimler cihazı titretmemeli veya ana ekrana düşmemeli.
   * Bu tür bilgilendirmeler sadece kullanıcı uygulamaya girip profilindeki "Bildirimler" sekmesine baktığında liste halinde (In-App Notification olarak) görünmeli.

**4. Kupon Kodu Bölümü ve 2. El Depo Ürünü İbaresi (Yeni Özellikler / UI-UX Güncellemesi)**
 * **Amaç:** Uygulamanın kullanım alanını genişletmek amacıyla kupon kodları için özel bir alan oluşturmak ve fırsat paylaşımlarında "2. El Depo Ürünü" olanları diğerlerinden şık bir şekilde ayırmak.
 * **İstenen Aksiyon:**
   * **Kupon Kodu Paylaşımı (Yeni Alan):** Uygulama içine, standart fırsat akışından bağımsız, kullanıcıların veya botların indirim kuponlarını paylaşabileceği ve kopyalayabileceği ayrı bir "Kuponlar" sekmesi/bölümü tasarlanıp eklenmeli.
   * **2. El Depo Ürünü İbaresi (Etiket):** Fırsat paylaşım ekranına "2. El Depo Ürünü" seçeneği (Checkbox/Toggle) eklenmeli. Bu seçenek işaretlenerek paylaşılan ürünlerin ana akıştaki kartlarında, o ürünün ikinci el depo ürünü olduğunu belirten, tasarım bütünlüğünü bozmayan şık ve belirgin bir etiket (Badge/İbare) yer almalı.

**5. Fırsat Paylaşımlarında Admin Onay Süreci (İş Akışı ve Güvenlik Güncellemesi)**
 * **Amaç:** Kullanıcıların paylaştığı fırsatların kontrolsüz bir şekilde doğrudan yayınlanmasını engellemek ve tüm içeriklerin ana akışa düşmeden önce bir admin onay süzgecinden geçmesini sağlamak.
 * **İstenen Aksiyon:**
   * **Beklemede (Pending) Statüsü:** Kullanıcı bir fırsat paylaştığında, veri tabanındaki gönderi statüsü varsayılan olarak "Beklemede" atanmalı ve bu statüdeki gönderiler ana akışta listelenmemelidir. Sadece Admin onay verdiğinde statü "Aktif"e dönmeli ve gönderi görünür olmalıdır.
   * **Sessiz Ret Bildirimi:** Paylaşılan fırsat Admin tarafından reddedilirse, 3. maddedeki kurguya uygun olarak kullanıcıya kesinlikle üstten cihaz bildirimi (Push Notification) gitmemelidir. Bunun yerine, ret detayı doğrudan uygulama içi "Bildirimler" sekmesine sessiz bir mesaj ("Paylaştığınız fırsat onaylanmadı" vb.) olarak düşmelidir.

**6. Mükerrer Link Paylaşımı Engeline Süre Sınırı (Cooldown) Getirilmesi (Mantık Güncellemesi)**
 * **Amaç:** Aynı ürün linkinin üst üste paylaşılarak spam oluşturmasını engellemek (mevcut iyi özellik), ancak aynı ürünün gün içinde tekrar indirime girme ihtimaline karşı bu engeli belirli bir zaman aşımına (cooldown) bağlamak.
 * **İstenen Aksiyon:**
   * Sistemdeki "aynı linki engelleme" mantığına bir zaman damgası (timestamp) kontrolü eklenmeli.
   * Kullanıcı veya bot bir link paylaştığında, veri tabanında bu linkin **en son ne zaman paylaşıldığı** kontrol edilmeli.
   * Eğer aynı link örneğin **son 24 saat** (veya belirlenecek makul bir süre) içinde paylaşılmışsa, yeni gönderi reddedilmeli.
   * Ancak önceki paylaşımın üzerinden belirlenen süre geçmişse, ürün fiyatının/kampanyasının yenilenmiş olabileceği varsayılarak linkin tekrar paylaşılmasına izin verilmelidir.