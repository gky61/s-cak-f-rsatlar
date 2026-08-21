Yeni scraping mekanizması:

scrape edilecek link: https://www.akakce.com/brosurler/

scrape edilecek mağazalara göre indirim kodlarını içeren linkler:

A-101: https://www.akakce.com/brosurler/a101
Bim: https://www.akakce.com/brosurler/bim
Şok: https://www.akakce.com/brosurler/sok
Migros: https://www.akakce.com/brosurler/migros
CarrefourSa: https://www.akakce.com/brosurler/carrefoursa
Çağrı: https://www.akakce.com/brosurler/cagrihipermarket
HappyCenter: https://www.akakce.com/brosurler/happy-center
MacroCenter: https://www.akakce.com/brosurler/macrocenter
GetirBüyük: https://www.akakce.com/brosurler/getirbuyuk
File: https://www.akakce.com/brosurler/filemarket
Hakmar Express: https://www.akakce.com/brosurler/hakmarexpress
Hakmar: https://www.akakce.com/brosurler/hakmar
Çetinkaya: https://www.akakce.com/brosurler/cetinkaya
Gratis: https://www.akakce.com/brosurler/gratis
Watsons: https://www.akakce.com/brosurler/watsons
Rossmann: https://www.akakce.com/brosurler/rossmann
Civil: https://www.akakce.com/brosurler/civil
Evkur: https://www.akakce.com/brosurler/evkur
MR.DIY: https://www.akakce.com/brosurler/mrdiy
Kooperatif Market: https://www.akakce.com/brosurler/kooperatifmarket
Metro: https://www.akakce.com/brosurler/metro-tr
Bizim Toptan: https://www.akakce.com/brosurler/bizimtoptan
Teknosa: https://www.akakce.com/brosurler/teknosacom
Vatan Bilgisayar: https://www.akakce.com/brosurler/vatanbilgisayar
Vestel: https://www.akakce.com/brosurler/vestel


Tüm linklerde yapı benzer zaten. Tekbir tanesi için eğer kuponları çekebilirsen diğerleri için de çalışacaktır. Şimdi sana  tek bir tanesi üzerinden nasıl bilgileri çekmen gerektiğini anlatacağım.

Sayfanın dom içeriğini sana komple atıcam. Bu dom'dan scrape edeceğiz tüm bilgileri.
Burdaki her bir mağaza için tüm broşürleri jpg olan hallerini ve gerekli bilgileri scrape ediceksin.

Mesela örnek bir madde domu üzerinden inceleme yapalım mağazamız BİM olsun diyelim:

<li><a href="/brosurler/bim-24-mart-2026-aktuel-katalogu-indirimli-urunler-56190"><div class="dt"><img alt="Bim İndirimli Ürünler" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/56190/56190_464539.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirimli Ürünler</span></div></div><span class="b">6 ay kaldı</span></a></li>

Bu örnekte gördüğün üzere : <span class="bn">İndirimli Ürünler</span> içerisinde broşürün kategorisi yazıyor bunu "katalogBasligi" kısmına ekleyebilirsin.
a href linkindeki değere tıkladığımızda ise şöyle bir url'e iste atılıyor: https://www.akakce.com/brosurler/bim-24-mart-2026-aktuel-katalogu-indirimli-urunler-56190

Bu url sonucu asıl fotoğraf/fotoğrafları alacağımız sayfa açılıyor. Bu açılan sayfada yüksek kaliteli fotoğrafı şöyle çekeceksin:

<div id="BP_W" class="bpgc"> <div class="p"><img alt="Bim 24 Mart 2026 Aktüel Kataloğu - sayfa 1" src="https://cdn.akakce.com/_bro/u/731/56190/56190_464539.jpg" style="width: 480.458px;"><span class="led gr" style="top: 61.83%; left: 35.23%;"></span><span class="rct rct_d" title="Terlik Kadın " style="width: 11.16%; height: 12.67%; top: 55.5%; left: 29.65%;"></span></div></div>

Tek bir resim olan örnek için buradaki jpg uzantılı url kullanabilirsin. 

Ancak birden fazla resim olan örnek için ise içerik şöyle olacak:

<div id="BP_W" class="bpgc"> <div class="p"><img alt="A101 16 Temmuz 2026 Aktüel Kataloğu - sayfa 1" src="https://cdn.akakce.com/_bro/u/3192/59290/59290_487877.jpg" style="width: 432.25px;"><span class="led g" style="top: 49.04%; left: 51.13%;"></span></div> <div class="p"><img alt="A101 16 Temmuz 2026 Aktüel Kataloğu - sayfa 2" src="https://cdn.akakce.com/_bro/u/3192/59290/59290_487878.jpg" style="width: 432.25px;"><span class="rct rct_d" title="Gölgelikli Salıncak" style="width: 42.23%; height: 28.42%; top: 41.92%; left: 0.75%;"></span></div> <div class="p"><img alt="A101 16 Temmuz 2026 Aktüel Kataloğu - sayfa 3" src="https://cdn.akakce.com/_bro/u/3192/59290/59290_487879.jpg" style="width: 432.25px;"><span class="rct rct_d" title="Seramik Salata Tabağı 21 cm " style="width: 20.93%; height: 14.42%; top: 75.92%; left: 72.31%;"></span></div></div>


Burada ise 3 tane farklı jpg var hepsini çekeceksin ve anlatılan mimariye uygun bir şekilde implemente edeceksin.

Örnek bir Tüm saydanın Dom yapısı:

<ul id="BLI" class="brl_v8"><li><a href="/brosurler/bim-24-mart-2026-aktuel-katalogu-indirimli-urunler-56190"><div class="dt"><img alt="Bim İndirimli Ürünler" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/56190/56190_464539.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirimli Ürünler</span></div></div><span class="b">6 ay kaldı</span></a></li><li><a href="/brosurler/bim-3-haziran-2026-aktuel-katalogu-firsat-indirim-58045"><div class="dt"><img alt="Bim Fırsat İndirim" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/58045/58045_478789.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">Fırsat İndirim</span></div></div><span class="b">1 ay kaldı</span></a></li><li><a href="/brosurler/bim-22-haziran-2026-aktuel-katalogu-indirim-brosuru-58665"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/58665/58665_483723.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">6 ay kaldı</span></a></li><li><a href="/brosurler/bim-1-temmuz-2026-aktuel-katalogu-indirimli-urunler-58911"><div class="dt"><img alt="Bim İndirimli Ürünler" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/58911/58911_484698.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirimli Ürünler</span></div></div><span class="b">2 hafta kaldı</span></a></li><li><a href="/brosurler/bim-14-temmuz-2026-aktuel-katalogu-indirim-brosuru-59089"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59089/59089_486432.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Son gün Pazartesi</span></a></li><li><a href="/brosurler/bim-15-temmuz-2026-aktuel-katalogu-indirim-brosuru-59090"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59090/59090_486431.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Son gün Salı</span></a></li><li><a href="/brosurler/bim-12-temmuz-2026-aktuel-katalogu-indirim-brosuru-59117"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59117/59117_486688.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Bugün son</span></a></li><li><a href="/brosurler/bim-7-temmuz-2026-aktuel-katalogu-firsat-indirim-59161"><div class="dt"><img alt="Bim Fırsat İndirim" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59161/59161_486930.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">Fırsat İndirim</span></div></div><span class="b">Son gün Pazartesi</span></a></li><li><a href="/brosurler/bim-19-temmuz-2026-aktuel-katalogu-indirim-brosuru-59235"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59235/59235_487651.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Yarın başlıyor</span></a></li><li><a href="/brosurler/bim-17-temmuz-2026-aktuel-katalogu-indirim-brosuru-59236"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59236/59236_487656.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Son gün Perşembe</span></a></li><li><a href="/brosurler/bim-11-temmuz-2026-aktuel-katalogu-facebook-paylasimi-59294"><div class="dt"><img alt="Bim Facebook Paylaşımı" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59294/59294_487886.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">Facebook Paylaşımı</span></div></div><span class="b">Son gün Cuma</span></a></li><li><a href="/brosurler/bim-21-temmuz-2026-aktuel-katalogu-indirim-brosuru-59302"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59302/59302_487904.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Salı başlıyor</span></a></li><li><a href="/brosurler/bim-22-temmuz-2026-aktuel-katalogu-indirim-brosuru-59303"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59303/59303_487907.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Çarşamba başlıyor</span></a></li><li><a href="/brosurler/bim-12-temmuz-2026-aktuel-katalogu-uygulamaya-ozel-59323"><div class="dt"><img alt="Bim Uygulamaya Özel" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59323/59323_488079.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">Uygulamaya Özel</span></div></div><span class="b">Bugün son</span></a></li><li><a href="/brosurler/bim-14-temmuz-2026-aktuel-katalogu-indirimli-urunler-59359"><div class="dt"><img alt="Bim İndirimli Ürünler" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59359/59359_488255.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirimli Ürünler</span></div></div><span class="b">Son gün Salı</span></a></li><li><a href="/brosurler/bim-14-temmuz-2026-aktuel-katalogu-firsat-indirim-59360"><div class="dt"><img alt="Bim Fırsat İndirim" src="//cdn.akakce.com/t.gif" style="background: url(&quot;https://cdn.akakce.com/_bro/y/731/59360/59360_488256.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">Fırsat İndirim</span></div></div><span class="b">2 hafta kaldı</span></a></li><li><a href="/brosurler/bim-10-temmuz-2026-aktuel-katalogu-instagram-postu-59392"><div class="dt"><img alt="Bim Instagram Post'u" src="//cdn.akakce.com/t.gif" style="min-width: 18px; min-height: 18px; background: url(&quot;https://cdn.akakce.com/_bro/y/731/59392/59392_488516.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">Instagram Post'u</span></div></div><span class="b">3 hafta kaldı</span></a></li><li><a href="/brosurler/bim-17-temmuz-2026-aktuel-katalogu-indirimli-urunler-59401"><div class="dt"><img alt="Bim İndirimli Ürünler" src="//cdn.akakce.com/t.gif" style="min-width: 18px; min-height: 18px; background: url(&quot;https://cdn.akakce.com/_bro/y/731/59401/59401_489089.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirimli Ürünler</span></div></div><span class="b">Son gün Pazartesi</span></a></li><li><a href="/brosurler/bim-24-temmuz-2026-aktuel-katalogu-indirim-brosuru-59455"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="min-width: 18px; min-height: 18px; background: url(&quot;https://cdn.akakce.com/_bro/y/731/59455/59455_489094.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">Cuma başlıyor</span></a></li><li><a href="/brosurler/bim-26-temmuz-2026-aktuel-katalogu-indirim-brosuru-59457"><div class="dt"><img alt="Bim İndirim Broşürü" src="//cdn.akakce.com/t.gif" style="min-width: 18px; min-height: 18px; background: url(&quot;https://cdn.akakce.com/_bro/y/731/59457/59457_489097.jpg&quot;) center center / contain no-repeat; opacity: 1;"><div class="blid"><b>Bim</b> <span class="bn">İndirim Broşürü</span></div></div><span class="b">1 hafta sonra başlıyor</span></a></li></ul>

## 🛡️ Mağaza Doğrulama ve Dinamik Mağaza Gizleme Mantığı

1. **Mağaza Eşleşme Doğrulaması (`catalog_scraper.js`):**
   - Akakçe üzerinde spesifik broşür sayfası bulunmayan mağaza URL'leri (örn: Macrocenter, Watsons) genel broşür sayfasına (`/brosurler/`) yönlenebilir.
   - Bu durumun alakasız mağaza broşürlerini (BİM, ŞOK, Hakmar vb.) yanlış mağazaya eklemesini önlemek için scraper'a **mağaza anahtar kelime eşleme kontrolü** eklenmiştir.
   - Broşür başlığındaki veya linkindeki mağaza adı hedeflenen mağazayla eşleşmiyorsa broşür elenir ve veritabanına eklenmez.

2. **Dinamik Mağaza Listeleme (`AktuelMagazalarPage`):**
   - Mobil uygulamada Aktüel Mağazalar ekranı Firestore'daki `kataloglar` koleksiyonunu canlı dinler.
   - Sadece yayında **aktif en az 1 kataloğu olan mağazalar** mağaza grid'inde görüntülenir. Aktif broşürü bulunmayan mağazalar ekranda otomatik olarak gizlenir.


