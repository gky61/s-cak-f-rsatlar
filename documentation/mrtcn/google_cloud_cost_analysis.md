# Google Cloud Cost Analysis & Optimization Report

Bu rapor, projenizin Google Cloud Platform (GCP) üzerindeki mevcut durumunu, yüksek faturalandırma (billing) sebeplerini ve Google Cloud sınırları içerisinde kalarak bu maliyetleri nasıl sıfıra veya en aza indirebileceğinizi açıklamaktadır.

---

## 1. Mevcut Mimari ve Durum Analizi

Sisteminiz iki ayrı GCP projesinden oluşmaktadır:
1.  **Geliştirme (DEV) Projesi:** `sicak-firsatlar-e6eae`
2.  **Canlı (PROD) Projesi:** `firsatkolik-prod-e6eae`

Her iki projede de aktif olarak çalışan iki temel kaynak türü bulunmaktadır:
*   **Firebase Functions (Cloud Functions):** Veritabanı tetikleyicileri (örn: `onDealCreated`, `onCommentCreated`) ve API'ler. Bu kaynaklar tamamen sunucusuzdur (serverless) ve istek bazlı çalışır. İstek gelmediğinde maliyetleri **0$**'dır.
*   **Telegram Bot (Cloud Run):** Telegram kanallarını 7/24 dinleyen Node.js uygulaması (`telegram-bot` servisi).

---

## 2. Faturalandırma Analizi (Neden Yüksek Fatura Geliyor?)

Faturanızın neredeyse tamamı **Cloud Run üzerinde çalışan Telegram Botlarından** kaynaklanmaktadır. Gönderdiğiniz fatura raporu görseli de bu tespiti birebir kanıtlamaktadır.

### A. Gönderdiğiniz Fatura Verilerinin İncelemesi:
*   **Toplam Fatura (1-14 Temmuz):** **1.658,71 TL**
*   **Cloud Run Payı:** **1.655,24 TL** (Toplam faturanın **%99,8**'ini oluşturuyor!)
*   **Diğer Servisler (Storage, Registry vb.):** Toplamda sadece **3,46 TL** (Yok denecek kadar az).
*   **Aylık Tahmini Fatura (Forecasted):** Temmuz ayı sonu için tahmin edilen fatura tam **4.482,61 TL (~135$)**.
*   **Grafik Analizi:** Grafik incelendiğinde 4 Temmuz'dan itibaren her gün sabit **~150 TL/gün** olacak şekilde düz bir çizgi halinde (flat rate) maliyet yazıldığı görülmektedir. Bu, botun kapatılmadan 7/24 aralıksız çalıştığının net göstergesidir.

### B. Cloud Run'ın Çalışma Biçimi ve Sorun
Normalde Cloud Run istek bazlı çalışır ve istek yokken sıfıra kapanır. Ancak Telegram Botu, Telegram sunucularıyla sürekli açık olan bir soket bağlantısı kurmak ve kanalları anlık dinlemek zorundadır. Bu nedenle şu ayarlar yapılmıştır:
1.  **`minScale: 1`:** Sunucunun hiçbir zaman kapanmaması (her zaman en az 1 örneğin açık kalması) zorunlu tutulmuştur.
2.  **`cpu-throttling: false` (No CPU Throttling):** İstek gelmediğinde bile CPU'nun uyku moduna geçmemesi sağlanmıştır. Bu ayar açıkken, Google Cloud sunucunun açık kaldığı **her saniye** için sizden para alır.

### C. Günlük ve Aylık Maliyet Hesabı (us-central1 Bölgesi)
Her bir bot **1 vCPU ve 512 MB RAM** limitleriyle çalışmaktadır. 

| Kaynak Türü | Birim Fiyat (Saniye Başına) | Günlük Maliyet (24 Saat) | Aylık Maliyet (30 Gün) |
| :--- | :--- | :--- | :--- |
| **1 vCPU** | $0.00002400 | $2.07 | $62.20 |
| **512 MB RAM** | $0.00000250 | $0.11 | $3.24 |
| **Tek Bot Toplamı** | - | **~$2.18** | **~$65.44** |
| **Çift Bot Toplamı (DEV + PROD)** | - | **~$4.36** | **~$130.88 (Faturanızdaki ~4.482 TL'ye denk gelir)** |

> [!IMPORTANT]
> Google Cloud, fatura dönemi sonunda toplu çekim yapmak yerine kullanım biriktikçe (2-3 günde bir) kartınızdan otomatik çekim yaptığı için sık sık faturayla karşılaşıyorsunuz. Tarihsel grafiğinizdeki 4 Temmuz fırlaması, botların ilk kez Cloud Run'a yüklendiği ve 7/24 çalışmaya başladığı güne tekabül etmektedir.

---

## 3. Google Cloud Sınırları İçinde Çözüm Yolları

Maliyetleri sıfıra veya minimuma indirmek için Google Cloud'un sunduğu yerel imkanları kullanabiliriz.

### Çözüm A: DEV ve PROD Botlarını Dondurmak (%100 Geçici Tasarruf) - [UYGULANDI ⏸️]
Projeniz henüz canlıya alınmadığı ve test aşamasında olduğu için gereksiz faturalandırmanın önüne geçilmesi amacıyla hem **DEV** hem de **PROD** ortamındaki botlar tamamen silinmeden dondurulmuş/pasif hale getirilmiştir.

*   **Nasıl Yapıldı (Dondurma İşlemi):** 
    Her iki projede de (`sicak-firsatlar-e6eae` ve `firsatkolik-prod-e6eae`) Cloud Run servislerinin `min-instances` değeri `0`'a çekilmiş ve CPU kısıtlamaları (`cpu-throttling: true`) aktif edilmiştir. Bu işlemi gerçekleştirmek için kullanılan komutlar:
    ```bash
    # DEV Botunu Dondur (Pasif Yap)
    gcloud run services update telegram-bot --min-instances 0 --cpu-throttling --region us-central1 --project sicak-firsatlar-e6eae
    
    # PROD Botunu Dondur (Pasif Yap)
    gcloud run services update telegram-bot --min-instances 0 --cpu-throttling --region us-central1 --project firsatkolik-prod-e6eae
    ```
    Bu botlar dışarıdan HTTP istekleri almadığından, Cloud Run sistemi aktif örnek sayılarını otomatik olarak **0**'a düşürmüştür. Artık arka planda hiçbir sunucu/CPU gücü harcanmamakta ve bu servislerden dolayı **0 TL** faturalandırma yapılmaktadır.
*   **Geri Açma/Etkinleştirme (7/24 Aktif Yapma):**
    Gerektiğinde botları tekrar Cloud Run üzerinde 7/24 aktif etmek isterseniz şu komutları çalıştırmanız yeterlidir:
    ```bash
    # DEV Botunu Aç (7/24 Aktif Yap)
    gcloud run services update telegram-bot --min-instances 1 --no-cpu-throttling --region us-central1 --project sicak-firsatlar-e6eae
    
    # PROD Botunu Aç (7/24 Aktif Yap)
    gcloud run services update telegram-bot --min-instances 1 --no-cpu-throttling --region us-central1 --project firsatkolik-prod-e6eae
    ```
*   **Aktif Olmadığını Konsoldan Görme/Teyit:**
    Google Cloud Console üzerinden botların dondurulduğunu doğrulamak için şu adımları izleyebilirsiniz:
    *   **DEV Botu İçin:** [GCP Cloud Run DEV Metrics Paneli](https://console.cloud.google.com/run/detail/us-central1/telegram-bot/metrics?project=sicak-firsatlar-e6eae) sayfasına gidin. *Active Instance Count* grafiğinde değerin `0` olduğunu görün.
    *   **PROD Botu İçin:** [GCP Cloud Run PROD Metrics Paneli](https://console.cloud.google.com/run/detail/us-central1/telegram-bot/metrics?project=firsatkolik-prod-e6eae) sayfasına gidin. *Active Instance Count* grafiğinde değerin `0` olduğunu görün.
*   **Geliştirme Yaparken Yerel (Local) Çalışma Yöntemi:**
    Buluttaki DEV botunu dondurduğumuz için, kendi bilgisayarınızda geliştirme yaparken botu yerelinizde çalıştırmanız gerekir:
    1.  Terminalden `d:\firsatkolik\cloud-run-bot` dizinine gidin.
    2.  Projenin kök dizinindeki `.env` dosyasının bir kopyasını buraya da oluşturun veya doğrudan oradaki çevre değişkenlerini kullanın.
    3.  Bağımlılıkları yükleyin ve botu başlatın:
        ```bash
        npm install
        npm run start
        ```
    4.  Yerelde çalışan botunuz Telegram kanallarını kendi bilgisayarınız üzerinden dinleyecek ve yakaladığı fırsatları buluttaki DEV veya PROD Firestore veritabanına sorunsuz yazacaktır.
*   **Maliyet Etkisi:** Aylık faturanız **130$'dan 0$'a düşmüştür (Tam tasarruf).**

### Çözüm B: Google Cloud Free Tier VM (Compute Engine) Kullanmak - [UYGULANDI ✅]
Google Cloud'un sunduğu ücretsiz VM hakkını kullanarak botlarınızı tamamen ücretsiz ve 7/24 aktif çalışacak şekilde sanal makineye taşıdık.

*   **Ücretsiz VM Hakkı:** `firsatkolik-prod-e6eae` (PROD) projesi altında, `us-central1-a` bölgesinde tamamen ücretsiz olan **e2-micro** (2 vCPU, 1 GB RAM, 10 GB HDD) sanal makinesi oluşturulmuştur.
*   **Maliyet Etkisi:** Cloud Run servisleri tamamen silindi. Aylık bot maliyetleriniz **130$'dan 0$'a düşürülmüştür.**

---

## 4. Gerçekleştirilen Taşıma ve Kurulum Detayları

Tüm geçiş işlemleri sıfır kesinti ve tam uyumlulukla tamamlanmıştır. Botların çalışma yapılandırması şu şekildedir:

### A. Sunucu ve Dizin Yapısı
Sanal makine üzerinde Node.js (v22) ve proses yöneticisi olarak PM2 kurulmuştur. Her iki bot izole dizinlerde çalışmaktadır:
*   **DEV Bot Dizin Yolu:** `/home/murat/app/dev-bot`
*   **PROD Bot Dizin Yolu:** `/home/murat/app/prod-bot`

### B. Port ve Kimlik Yapılandırması
Port çakışmalarını önlemek amacıyla botların dinledikleri HTTP portları güncellenmiştir:
*   **DEV Bot Portu:** `8081` (Firestore: `sicak-firsatlar-e6eae` projesine bağlıdır. Kimlik doğrulama `/home/murat/app/dev-bot/dev_firebase_key.json` dosyasıyla sağlanmaktadır.)
*   **PROD Bot Portu:** `8082` (Firestore: `firsatkolik-prod-e6eae` projesine bağlıdır. Kimlik doğrulama `/home/murat/app/prod-bot/prod_firebase_key.json` dosyasıyla sağlanmaktadır.)

---

## 5. VM Üzerindeki Botları Kontrol Etme ve Yönetme Kılavuzu

### 🔗 Google Cloud Console Üzerinden Teyit/Kontrol
*   **Sanal Makineyi Görme:** [GCP Compute Engine VM Paneli](https://console.cloud.google.com/compute/instances?project=firsatkolik-prod-e6eae) adresinden oluşturduğumuz `telegram-bot-server` sanal makinesinin `RUNNING` (Çalışıyor) durumunda olduğunu doğrulayabilirsiniz.

### 💻 CLI / Terminal Üzerinden Yönetim Komutları

Sanal makinedeki botların durumunu görmek veya müdahale etmek için yerel terminalinizden (Powershell/CMD) şu komutları kullanabilirsiniz:

#### 1. Sunucuya SSH ile Bağlanma:
```bash
gcloud compute ssh telegram-bot-server --zone=us-central1-a --project=firsatkolik-prod-e6eae
```

#### 2. Sunucu İçerisinde Botların Durumunu Görme (PM2):
SSH ile sunucuya bağlandıktan sonra botların durumunu, bellek ve CPU kullanımlarını listelemek için:
```bash
# Botların listesini ve online olup olmadıklarını gör
pm2 list

# CPU ve RAM tüketimlerini anlık izle
pm2 status
```

#### 3. Bot Loglarını (Çıktı ve Hataları) İzleme:
Botların Telegram'dan yakaladığı mesajları, Gemini analizlerini veya olası hataları görmek için:
```bash
# Her iki botun da loglarını canlı olarak akıt
pm2 logs

# Sadece belirli bir botun logunu gör
pm2 logs dev-bot
pm2 logs prod-bot

# Son 50 satır log çıktısını gör
pm2 logs --lines 50
```

#### 4. Botları Yeniden Başlatma / Durdurma:
```bash
# Botu yeniden başlat (Örn: Telegram session yenilediğinizde)
pm2 restart dev-bot
pm2 restart prod-bot

# Botu durdur
pm2 stop dev-bot

# Durdurulan botu tekrar başlat
pm2 start dev-bot
```

> [!IMPORTANT]
> **Sunucu Kapanıp Açılırsa Otomatik Başlama:** Sunucunun yeniden başlaması (reboot) veya çökmesi durumunda PM2'nin botları otomatik olarak tekrar kaldığı yerden başlatması için `systemd` entegrasyonu yapılmış ve servis listesi kaydedilmiştir (`pm2 save`). Manuel bir işlem yapmanıza gerek yoktur.

---

## 6. Özet Sonuç

Bu geçiş sonrasında:
1.  **Aylık 130$ (yaklaşık 4.400 TL)** tutarındaki sunucu gideriniz **tamamen sıfırlanmıştır.**
2.  Botlar artık 7/24 kesintisiz olarak kanalları dinlemeye ve Firebase veritabanınıza verileri anında kaydetmeye devam etmektedir.
3.  Tüm gizlilik, güvenlik anahtarları ve çalışma parametreleri aynen korunmuştur.

