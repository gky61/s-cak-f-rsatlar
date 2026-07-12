import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/category.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class CategoryDetectionService {
  static final CategoryDetectionService _instance = CategoryDetectionService._internal();
  factory CategoryDetectionService() => _instance;
  CategoryDetectionService._internal();

  // Kategori ve alt kategori için keyword eşleştirmeleri
  static final Map<String, Map<String, List<String>>> _categoryKeywords = {
    'elektronik': {
      'Telefon & Aksesuarları': [
        'telefon', 'iphone', 'samsung', 'xiaomi', 'huawei', 'oppo', 'vivo', 'realme', 'oneplus', 'honor', 'poco', 'redmi',
        'akıllı telefon', 'akilli telefon', 'cep telefonu', 'mobil telefon', 'telefon kılıfı', 'telefon kilifi', 'telefon camı', 'telefon cami',
        'telefon kılıf', 'telefon kilif', 'telefon kapağı', 'telefon kapagi', 'telefon şarj', 'telefon sarj',
        'powerbank', 'power bank', 'powerbank', 'şarj aleti', 'sarj aleti', 'şarj cihazı', 'sarj cihazi', 'şarj kablosu', 'sarj kablosu',
        'kablosuz şarj', 'kablosuz sarj', 'wireless charger', 'qi charger', 'fast charge', 'hızlı şarj', 'hizli sarj',
        'kulaklık', 'kulaklik', 'airpods', 'earbuds', 'kablosuz kulaklık', 'kablosuz kulaklik', 'bluetooth kulaklık', 'bluetooth kulaklik',
        'tws', 'true wireless', 'kulak içi', 'kulak ici', 'over ear', 'on ear', 'kulak üstü', 'kulak ustu',
        'telefon aksesuar', 'telefon aksesuari', 'ekran koruyucu', 'screen protector', 'tempered glass', 'cam film',
        'telefon standı', 'telefon standi', 'telefon tutacağı', 'telefon tutacagi', 'selfie stick', 'selfie çubuğu',
        'phone', 'smartphone', 'mobile', 'cell phone', 'charger', 'case', 'headphone', 'earphone', 'earbud', 'headset',
        'galaxy', 'note', 's series', 'a series', 'pixel', 'motorola', 'nokia', 'sony', 'lg'
      ],
      'Bilgisayar & Tablet': [
        'tablet', 'ipad', 'android tablet', 'windows tablet', 'tablet pc', 'tablet bilgisayar', 'tablet bilgisayarı',
        'ipad pro', 'ipad air', 'ipad mini', 'galaxy tab', 'huawei tablet', 'lenovo tablet', 'surface tablet',
        'laptop', 'notebook', 'macbook', 'macbook pro', 'macbook air', 'surface', 'surface pro', 'surface laptop',
        'chromebook', '2 in 1', 'convertible', 'hybrid laptop', 'gaming laptop', 'oyun laptop', 'iş laptop', 'is laptop',
        'bilgisayar', 'pc', 'masaüstü', 'desktop', 'all in one', 'aio', 'imac', 'mac mini',
        'monitör', 'monitor', 'ekran', 'curved monitor', 'gaming monitor', '4k monitor', 'ultrawide',
        'klavye', 'keyboard', 'mekanik klavye', 'gaming klavye', 'wireless klavye', 'kablosuz klavye',
        'mouse', 'fare', 'gaming mouse', 'wireless mouse', 'kablosuz mouse', 'trackpad', 'touchpad',
        'webcam', 'kamera', 'mikrofon', 'microphone', 'hoparlör', 'speaker', 'ses sistemi',
        'yazıcı', 'printer', 'lazer yazıcı', 'mürekkep püskürtmeli', 'murekkep puskurtmeli', 'scanner', 'tarayıcı',
        'harddisk', 'hard disk', 'hdd', 'ssd', 'nvme', 'm2 ssd', 'external harddisk', 'harici disk',
        'usb bellek', 'flash bellek', 'usb drive', 'hafıza kartı', 'memory card', 'sd kart', 'micro sd', 'sdhc', 'sdxc',
        'ram', 'memory', 'bellek', 'graphics card', 'ekran kartı', 'ekran karti', 'gpu', 'cpu', 'işlemci', 'islemci',
        'modem', 'router', 'access point', 'menzil genişletici', 'menzil genisletici', 'tp-link', 'keenetic', 'asus router', 'tenda', 'xiaomi router', 'network', 'ağ', 'ag'
      ],
      'TV & Ses Sistemleri': [
        'televizyon', 'tv', 'smart tv', 'led tv', 'oled', 'qled', 'qled tv', '4k tv', '8k tv', 'ultra hd',
        'samsung tv', 'lg tv', 'sony tv', 'philips tv', 'tcl tv', 'xiaomi tv', 'vestel tv',
        'soundbar', 'sound bar', 'ses çubuğu', 'ses cubugu', 'dolby atmos', 'surround sound',
        'hoparlör', 'speaker', 'bluetooth hoparlör', 'kablosuz hoparlör', 'wireless speaker', 'portable speaker',
        'ses sistemi', 'audio system', 'home theater', 'ev sineması', 'ev sinemasi', '5.1', '7.1',
        'projeksiyon', 'projector', 'projeksiyon cihazı', 'projeksiyon cihazi', '4k projector',
        'anten', 'anten çanak', 'anten canak', 'uydu alıcı', 'uydu alici', 'satellite receiver',
        'tv kutusu', 'tv box', 'android tv box', 'chromecast', 'fire tv', 'apple tv', 'mi box',
        'subwoofer', 'woofer', 'tweeter', 'amplifier', 'amplifikatör', 'receiver', 'alıcı', 'alici'
      ],
      'Beyaz Eşya & Küçük Ev Aletleri': [
        'buzdolabı', 'buzdolabi', 'refrigerator', 'fridge', 'no frost', 'no-frost', 'derin dondurucu', 'freezer',
        'çamaşır makinesi', 'camasir makinesi', 'washing machine', 'yıkama makinesi', 'yikama makinesi',
        'bulaşık makinesi', 'bulasik makinesi', 'dishwasher', 'bulaşık yıkama', 'bulasik yikama',
        'fırın', 'firin', 'oven', 'elektrikli fırın', 'elektrikli firin', 'mikrodalga', 'microwave',
        'ocak', 'induction', 'indüksiyon', 'induksiyon', 'cam ocak', 'gaz ocağı', 'gaz ocagi',
        'klima', 'air conditioner', 'split klima', 'portable klima', 'taşınabilir klima', 'tasinabilir klima',
        'vantilatör', 'vantilator', 'fan', 'hava temizleyici', 'hava temizleme', 'air purifier', 'nem alma',
        'aspiratör', 'hood', 'mutfak aspiratörü', 'mutfak aspiratoru', 'davlumbaz',
        'elektrikli süpürge', 'elektrikli supurge', 'vacuum cleaner', 'dikey süpürge', 'dikey supurge',
        'robot süpürge', 'robot supurge', 'robot vacuum', 'roomba', 'dyson', 'xiaomi robot',
        'süpürge', 'supurge',
        'ütü', 'utu', 'iron', 'buharlı ütü', 'buharli utu', 'steam iron',
        'kahve makinesi', 'coffee maker', 'espresso makinesi', 'espresso makine', 'filtre kahve makinesi', 'turk kahve makinesi', 'turk kahvesi makinesi',
        'su ısıtıcı', 'su isiticisi', 'kettle', 'electric kettle', 'çaydanlık', 'caydanlik',
        'tost makinesi', 'toaster', 'sandwich maker', 'tost', 'waffle maker', 'waffle makinesi',
        'mikser', 'mixer', 'hand mixer', 'el mikseri', 'stand mixer', 'ayaklı mikser', 'ayakli mikser',
        'blender', 'smoothie maker', 'mutfak robotu', 'food processor', 'rondo',
        'mini buzdolabı', 'mini buzdolabi', 'mini fridge', 'camping fridge',
        'airfryer', 'fritöz', 'fritoz', 'air fryer',
        'tıraş makinesi', 'tiras makinesi', 'epilatör', 'epilator', 'saç kurutma', 'sac kurutma',
        'fön makinesi', 'fon makinesi', 'düzleştirici', 'duzlestirici', 'maşa', 'saç şekillendirici',
        'sac sekillendirici', 'sakal şekillendirici', 'sakal sekillendirici', 'epilasyon cihazı', 'epilasyon cihazi'
      ],
      'Fotoğraf & Kamera': [
        'foto', 'fotoğraf', 'fotograf',
        'kamera', 'camera', 'fotoğraf makinesi', 'fotograf makinesi', 'dijital kamera', 'digital camera',
        'dslr', 'mirrorless', 'aps-c', 'full frame', 'canon', 'nikon', 'sony camera', 'fujifilm',
        'action kamera', 'action camera', 'go pro', 'gopro', 'hero', 'insta360', 'dji action',
        'drone', 'quadcopter', 'dji drone', 'mavic', 'phantom', 'mini drone', 'fpv drone',
        'lens', 'objektif', 'telephoto', 'wide angle', 'macro', 'prime lens', 'zoom lens',
        'tripod', 'üç ayak', 'uc ayak', 'monopod', 'gimbal', 'stabilizer', 'selfie stick',
        'kamera aksesuar', 'camera accessory', 'kamera çantası', 'camera bag', 'filtre', 'filter',
        'hafıza kartı', 'memory card', 'cf card', 'cfexpress', 'xqd', 'batarya', 'battery', 'şarj cihazı', 'charger',
        'flash', 'flaş', 'flash', 'external flash', 'harici flaş', 'softbox', 'diffuser'
      ],
      'Akıllı Ev & Güvenlik': [
        'akıllı priz', 'akilli priz', 'akıllı ampul', 'akilli ampul', 'akıllı lamba', 'akilli lamba',
        'güvenlik kamerası', 'guvenlik kamerasi', 'ip kamera', 'akıllı kilit', 'akilli kilit',
        'hareket sensörü', 'hareket sensoru', 'akıllı ev', 'akilli ev', 'ring kamera', 'tuya',
        'sonoff', 'xiaomi sensor', 'akilli termostat', 'akıllı termostat', 'smart home'
      ]
    },
    'moda': {
      'Kadın Giyim': [
        'kadın', 'kadin', 'kadın giyim', 'kadin giyim', 'women', "women's", 'bayan', 'bayan giyim',
        'elbise', 'dress', 'maxi elbise', 'midi elbise', 'mini elbise', 'cocktail dress', 'gece elbisesi',
        'bluz', 'blouse', 'gömlek', 'gomlek', 'shirt', 'pantolon', 'pants', 'jean', 'jeans', 'skinny', 'straight',
        'etek', 'skirt', 'mini etek', 'midi etek', 'maxi etek', 'pencil skirt', 'kalem etek',
        'şort', 'sort', 'shorts', 'bermuda', 'ceket', 'jacket', 'blazer', 'denim ceket', 'deri ceket',
        'mont', 'coat', 'kaban', 'parka', 'trençkot', 'trenckot', 'trench coat', 'windbreaker',
        'sweatshirt', 'sweat', 'hoodie', 'tişört', 'tisort', 't-shirt', 'tshirt', 'polo',
        'kazak', 'sweater', 'cardigan', 'hırka', 'hirka', 'tayt', 'leggings', 'yoga pant', 'jogger',
        'pijama', 'pajama', 'pijama takımı', 'pijama takimi', 'gece elbisesi', 'nightgown',
        'iç çamaşırı', 'ic camasiri', 'underwear', 'lingerie', 'sütyen', 'sutyen', 'bra', 'bralette',
        'çorap', 'corap', 'socks', 'tayt çorap', 'tayt corap', 'pantyhose', 'tights',
        'kadın ayakkabı', 'kadin ayakkabi', 'women shoes', 'topuklu', 'heels', 'high heels', 'stiletto',
        'babet', 'ballet flat', 'sandalet', 'sandal', 'flip flop', 'bot', 'boots', 'çizme', 'cizme',
        'kadın çanta', 'kadin canta', 'women bag', 'el çantası', 'el cantasi', 'handbag', 'clutch',
        'sırt çantası', 'sirt cantasi', 'backpack', 'crossbody', 'shoulder bag', 'tote bag',
        'dress', 'blouse', 'shirt', 'pants', 'jeans', 'skirt', 'jacket', 'coat', 'sweater', 'top', 'tank top'
      ],
      'Erkek Giyim': [
        'erkek', 'erkek giyim', 'men', "men's", 'bay', 'bay giyim',
        'pijama', 'pajama', 'pijama takımı', 'pijama takimi',
        'gömlek', 'gomlek', 'shirt', 'dress shirt', 'casual shirt', 'oxford shirt', 'polo shirt',
        'pantolon', 'pants', 'jean', 'jeans', 'chino', 'kısa pantolon', 'kisa pantolon', 'cargo pants',
        'şort', 'sort', 'shorts', 'bermuda shorts', 'swim shorts', 'yüzme şortu', 'yuzme sortu',
        'tişört', 'tisort', 't-shirt', 'tshirt', 'v-neck', 'crew neck', 'tank top', 'muscle shirt',
        'polo', 'polo shirt', 'kazak', 'sweater', 'cardigan', 'hoodie', 'sweatshirt', 'sweat',
        'ceket', 'jacket', 'denim jacket', 'deri ceket', 'leather jacket', 'bomber', 'blazer',
        'mont', 'coat', 'kaban', 'parka', 'trençkot', 'trenckot', 'trench coat', 'windbreaker',
        'takım elbise', 'takim elbise', 'suit', 'business suit', 'formal suit', 'yelek', 'vest',
        'iç çamaşırı', 'ic camasiri', 'underwear', 'boxer', 'boxer brief', 'brief', 'boxer short',
        'çorap', 'corap', 'socks', 'anklet', 'crew socks', 'no-show socks',
        'erkek ayakkabı', 'erkek ayakkabi', "men's shoes", 'spor ayakkabı', 'spor ayakkabi', 'sneakers',
        'klasik ayakkabı', 'klasik ayakkabi', 'dress shoes', 'oxford', 'derby', 'loafer',
        'bot', 'boots', 'work boots', 'hiking boots', 'terlik', 'slippers', 'sandalet', 'sandal',
        'shirt', 'pants', 'jeans', 't-shirt', 'tshirt', 'polo', 'sweater', 'jacket', 'coat', 'suit'
      ],
      'Ayakkabı & Çanta': [
        'ayakkabı', 'ayakkabi', 'shoe', 'shoes', 'spor ayakkabı', 'spor ayakkabi', 'sneakers', 'sneaker',
        'krampon', 'cleats', 'futbol ayakkabısı', 'futbol ayakkabisi', 'basketbol ayakkabısı', 'basketbol ayakkabisi',
        'bot', 'boots', 'work boots', 'hiking boots', 'çizme', 'cizme', 'ankle boots', 'chelsea boots',
        'terlik', 'slippers', 'sandalet', 'sandal', 'flip flops', 'topuklu', 'heels', 'high heels',
        'babet', 'ballet flats', 'balerin', 'loafer', 'moccasin', 'oxford', 'derby',
        'çanta', 'canta', 'bag', 'handbag', 'el çantası', 'el cantasi', 'clutch', 'tote bag',
        'sırt çantası', 'sirt cantasi', 'backpack', 'rucksack', 'crossbody bag', 'shoulder bag',
        'laptop çantası', 'laptop cantasi', 'laptop bag', 'messenger bag', 'valiz', 'bavul', 'suitcase', 'luggage',
        'cüzdan', 'cuzdan', 'wallet', 'card holder', 'kemer', 'belt', 'leather belt',
        'güneş gözlüğü', 'gunes gozlugu', 'sunglasses', 'şapka', 'sapka', 'hat', 'cap', 'baseball cap',
        'bere', 'beanie', 'eldiven', 'gloves', 'atkı', 'atki', 'scarf', 'şal', 'sal'
      ],
      'Saat, Aksesuar & Takı': [
        'saat', 'watch', 'wristwatch', 'timepiece', 'kol saati', 'akıllı saat', 'smartwatch', 'apple watch',
        'galaxy watch', 'fitbit', 'garmin', 'huawei watch', 'xiaomi watch', 'fossil watch',
        'saat kordonu', 'watch strap', 'watch band', 'saat kayışı', 'watch bracelet', 'leather strap',
        'dijital saat', 'digital watch', 'analog saat', 'analog watch', 'kronograf', 'chronograph',
        'otomatik saat', 'automatic watch', 'quartz saat', 'quartz watch', 'mekanik saat', 'mechanical watch',
        'gps saat', 'gps watch', 'fitness saat', 'fitness watch', 'spor saat', 'sports watch',
        'diving watch', 'dalış saati', 'dalis saati', 'pilot watch', 'pilot saati',
        'aksesuar', 'accessory', 'kemer', 'belt', 'cüzdan', 'wallet', 'card holder',
        'güneş gözlüğü', 'gunes gozlugu', 'sunglasses', 'ray-ban', 'oakley', 'şapka', 'sapka', 'hat', 'cap',
        'bere', 'beanie', 'eldiven', 'gloves', 'atkı', 'atki', 'scarf', 'şal', 'sal',
        'kolye', 'necklace', 'küpe', 'earrings', 'yüzük', 'ring', 'bilezik', 'bracelet', 'bileklik', 'anklet',
        'brooch', 'rozet', 'tie', 'kravat', 'cufflinks', 'kol düğmesi', 'kol dugmesi',
        'altın kolye', 'altin kolye', 'gümüş kolye', 'gumus kolye', 'altın bileklik', 'altin bileklik',
        'gümüş bileklik', 'gumus bileklik', 'altın yüzük', 'altin yuzuk', 'gümüş yüzük', 'gumus yuzuk',
        'altın küpe', 'altin kupe', 'gümüş küpe', 'gumus kupe', 'pırlanta', 'pirlanta', 'elmas',
        'safir', 'yakut', 'zümrüt', 'zumrut', 'altın zincir', 'altin zincir', 'takı seti', 'taki seti',
        'çelik kolye', 'celik kolye', 'çelik bileklik', 'celik bileklik', 'tektaş', 'tektas', 'beştaş', 'bestas'
      ],
      'Çocuk Giyim': [
        'çocuk', 'cocuk', 'bebek', 'çocuk giyim', 'cocuk giyim', 'bebek giyim', "children's", "kids'", "baby",
        'çocuk elbise', 'cocuk elbise', 'bebek elbise', 'çocuk pantolon', 'cocuk pantolon', 'bebek pantolon',
        'çocuk tişört', 'cocuk tisort', 'bebek tişört', 'çocuk kazak', 'cocuk kazak', 'bebek kazak',
        'çocuk mont', 'cocuk mont', 'bebek mont', 'çocuk ceket', 'cocuk ceket', 'bebek ceket',
        'çocuk ayakkabı', 'cocuk ayakkabi', "children's shoes", "kids' shoes", 'bebek ayakkabı', 'bebek ayakkabi',
        'okul kıyafeti', 'okul kiyafeti', 'school uniform', 'okul forması', 'okul formasi',
        'çocuk çanta', 'cocuk canta', "kids' bag", 'bebek çanta', 'bebek canta', 'okul çantası', 'okul cantasi',
        'çocuk iç çamaşırı', 'cocuk ic camasiri', "children's underwear"
      ],
    },
    'ev_yasam': {
      'Mobilya': [
        'mobilya', 'furniture', 'kanepe', 'sofa', 'koltuk', 'armchair', 'recliner', 'lazy boy',
        'masa', 'table', 'yemek masası', 'yemek masasi', 'dining table', 'çalışma masası', 'calisma masasi',
        'sandalye', 'chair', 'dining chair', 'ofis koltuğu', 'office chair', 'gaming chair',
        'yatak', 'bed', 'yatak odası', 'yatak odasi', 'bedroom', 'yatak takımı', 'yatak takimi',
        'dolap', 'wardrobe', 'gardırop', 'gardrop', 'komodin', 'nightstand', 'sehpa', 'coffee table',
        'tv ünitesi', 'tv unitesi', 'tv stand', 'tv cabinet', 'kitaplık', 'kitaplik', 'bookshelf',
        'raflı dolap', 'rafli dolap', 'shelf', 'mutfak dolabı', 'mutfak dolabi', 'kitchen cabinet',
        'banyo dolabı', 'banyo dolabi', 'bathroom cabinet', 'vanity', 'banyo aynası', 'bathroom mirror',
        'konsol', 'console table', 'şifonyer', 'sifonyer', 'dresser', 'vitrin', 'display cabinet'
      ],
      'Ev Tekstili': [
        'çarşaf', 'carsaf', 'sheet', 'bedsheet', 'yorgan', 'comforter', 'duvet', 'battaniye', 'blanket',
        'yastık', 'pillow', 'yastık kılıfı', 'yastik kilifi', 'pillowcase', 'nevresim', 'bedding',
        'perde', 'curtain', 'drap', 'tül', 'tul', 'sheer curtain', 'blackout curtain',
        'halı', 'carpet', 'rug', 'kilim', 'kilim rug', 'paspas', 'doormat', 'welcome mat',
        'havlu', 'towel', 'banyo havlusu', 'banyo havlusu', 'bath towel', 'bornoz', 'bathrobe',
        'terlik', 'slippers', 'ev terliği', 'ev terligi', 'house slippers', 'bathroom slippers',
        'minder', 'cushion', 'yastık', 'throw pillow', 'decorative pillow'
      ],
      'Mutfak Gereçleri': [
        'tava', 'pan', 'frying pan', 'wok', 'tava seti', 'pan set', 'tencere', 'pot', 'saucepan',
        'tencere seti', 'pot set', 'bıçak', 'bicak', 'knife', 'bıçak seti', 'bicak seti', 'knife set',
        'kesme tahtası', 'kesme tahtasi', 'cutting board', 'chopping board', 'saklama kabı', 'saklama kabi',
        'storage container', 'tupperware', 'cam kavanoz', 'cam kavanoz', 'glass jar', 'mason jar',
        'termos', 'thermos', 'su şişesi', 'su sisesi', 'water bottle', 'fincan', 'cup', 'mug',
        'bardak', 'glass', 'wine glass', 'tabak', 'plate', 'çatal', 'catal', 'fork',
        'kaşık', 'kasik', 'spoon', 'servis takımı', 'servis takimi', 'dinnerware', 'tableware',
        'yemek takımı', 'yemek takimi', 'sofra',
        'çaydanlık', 'caydanlik', 'teapot', 'french press', 'kahve fincanı', 'kahve fincani', 'coffee cup',
        'servis tabağı', 'servis tabagi', 'serving plate', 'salata kasesi', 'salad bowl'
      ],
      'Aydınlatma & Dekorasyon': [
        'lamba', 'lamp', 'table lamp', 'floor lamp', 'desk lamp', 'avize', 'chandelier', 'ceiling light',
        'aydınlatma', 'aydinlatma', 'lighting', 'led', 'led strip', 'led light', 'ampul', 'bulb', 'light bulb',
        'dekorasyon', 'decoration', 'home decor', 'duvar saati', 'duvar saati', 'wall clock',
        'resim', 'picture', 'tablo', 'painting', 'canvas', 'vazo', 'vase', 'mum', 'candle',
        'mumluk', 'candle holder', 'ayna', 'mirror', 'wall mirror', 'bathroom mirror',
        'panjur', 'blinds', 'stor', 'roller blind', 'jaluzi', 'venetian blind', 'blackout blind',
        'picture frame', 'resim çerçevesi', 'resim cercevesi', 'wall art', 'duvar sanatı', 'duvar sanati',
        'plant', 'bitki', 'saksı', 'saksi', 'pot', 'plant pot'
      ],
      'Kırtasiye & Ofis Malzemeleri': [
        'kalem', 'pen', 'pencil', 'defter', 'notebook', 'ajanda', 'planner', 'agenda',
        'dosya', 'file', 'klasör', 'klasor', 'folder', 'zarf', 'envelope',
        'kağıt', 'kagit', 'paper', 'a4', 'a4 paper', 'yazıcı kağıdı', 'yazici kagidi', 'printer paper',
        'mürekkepli kalem', 'murekkep kalem', 'fountain pen', 'tükenmez kalem', 'tukenmez kalem', 'ballpoint pen',
        'kurşun kalem', 'kursun kalem', 'pencil', 'silgi', 'eraser', 'kalemtraş', 'pencil sharpener',
        'kırtasiye', 'kirtasiye', 'makas', 'scissors', 'yapıştırıcı', 'yapistirici', 'glue', 'bant', 'tape', 'scotch tape',
        'zımba', 'zimba', 'stapler', 'zımba teli', 'zimba teli', 'staple', 'delgeç', 'hole punch',
        'not defteri', 'not defteri', 'notepad', 'post it', 'post-it', 'sticky note', 'etiket', 'label',
        'marker', 'kalem', 'highlighter', 'vurgulayıcı', 'vurgulayici', 'ruler', 'cetvel', 'compass', 'pergel'
      ],
    },
    'anne_bebek': {
      'Bebek Bezi & Islak Mendil': [
        'bebek bezi', 'diaper', 'nappy', 'bez', 'pampers', 'huggies', 'molfix',
        'ıslak mendil', 'islak mendil', 'wet wipes', 'bebek mendili', 'baby wipes',
        'alt açma', 'diaper changing', 'pişik kremi', 'pisik kremi', 'diaper rash cream',
        'bebek bakım', 'bebek bakim', 'baby care', 'bebek losyonu', 'baby lotion',
        'bebek şampuanı', 'bebek sampuani', 'baby shampoo', 'bebek sabunu', 'baby soap'
      ],
      'Bebek Arabası & Oto Koltuğu': [
        'bebek arabası', 'bebek arabasi', 'stroller', 'puset', 'pram', 'baby carriage',
        'oyuncak arabası', 'oyuncak arabasi', 'toy car', 'oto koltuğu', 'oto koltuğu', 'car seat',
        'bebek koltuğu', 'bebek koltuğu', 'baby seat', 'araç koltuğu', 'arac koltuğu', 'vehicle seat',
        'bebek taşıyıcı', 'bebek tasiyici', 'baby carrier', 'kanguru', 'kangaroo carrier',
        'sling', 'baby sling', 'ergonomic carrier', 'bebek askısı', 'bebek askisi',
        'bebek bakım çantası', 'bebek bakim cantasi', 'bebek çantası', 'bebek cantasi',
        'anne bebek çantası', 'anne bebek cantasi', 'alt açma çantası', 'alt acma cantasi'
      ],
      'Beslenme & Emzirme': [
        'biberon', 'bottle', 'baby bottle', 'emzik', 'pacifier', 'dummy', 'emzirme', 'mama', 'göğüs', 'gogus',
        'biberon emziği', 'biberon emzigi', 'baby bottle nipple', 'teat',
        'mama kabı', 'mama kabi', 'feeding bowl', 'mama kaşığı', 'mama kasigi', 'feeding spoon',
        'suluk', 'sippy cup', 'bebek çatalı', 'bebek catali', 'baby fork',
        'emzirme yastığı', 'emzirme yastigi', 'nursing pillow', 'göğüs pompası', 'gogus pompasi',
        'breast pump', 'süt saklama', 'sut saklama', 'breast milk storage', 'mama ısıtıcı', 'mama isiticisi',
        'bottle warmer', 'sterilizatör', 'sterilizer', 'biberon sterilizatörü',
        'devam sütü', 'devam sutu', 'bebek maması', 'bebek mamasi', 'aptamil', 'sma', 'milupa', 'bebelac', 'hipp'
      ],
      'Bebek Odası & Güvenlik': [
        'bebek yatağı', 'bebek yatagi', 'baby bed', 'beşik', 'besik', 'crib', 'bebek karyolası',
        'bebek karyolasi', 'baby crib', 'bebek odası', 'bebek odasi', 'nursery', 'bebek mobilya',
        'bebek mobilya', 'baby furniture', 'bebek güvenlik', 'bebek guvenlik', 'baby safety',
        'bebek kapısı', 'bebek kapisi', 'baby gate', 'priz koruyucu', 'outlet cover',
        'köşe koruyucu', 'kose koruyucu', 'corner guard', 'bebek monitörü', 'baby monitor',
        'telsiz', 'bebek telsizi', 'telsizi',
        'bebek', 'baby'
      ],
      'Bebek & Çocuk Oyuncakları': [
        'bebek oyuncak', 'bebek oyuncak', 'baby toy', 'oyuncak', 'toy', 'eğitici oyuncak',
        'egitici oyuncak', 'educational toy', 'bebek oyuncağı', 'bebek oyuncagi',
        'peluş oyuncak', 'pelus oyuncak', 'plush toy', 'stuffed animal', 'doll',
        'oyuncak araba', 'toy car', 'duplo', 'building blocks', 'pilsan', 'akülü araba', 'akulu araba',
        'bebek oyun halısı', 'play mat', 'activity gym', 'müzikli oyuncak', 'musical toy'
      ],
    },
    'kozmetik': {
      'Parfüm & Deodorant': [
        'parfüm', 'parfum', 'perfume', 'kolonya', 'cologne', 'deodorant', 'roll on', 'sprey', 'spray',
        'parfüm seti', 'parfum seti', 'perfume set', 'kadın parfüm', 'kadin parfum', "women's perfume",
        'erkek parfüm', 'erkek parfum', "men's perfume", 'unisex parfüm', 'unisex parfum',
        'body spray', 'vücut spreyi', 'vucut spreyleri', 'deo', 'antiperspirant'
      ],
      'Makyaj Ürünleri': [
        'ruj', 'lipstick', 'fondöten', 'foundation', 'kapatıcı', 'kapatıcı', 'concealer',
        'pudra', 'powder', 'allık', 'blush', 'fırça', 'firca', 'brush', 'makyaj fırçası',
        'makyaj fircasi', 'makeup brush', 'göz kalemi', 'goz kalemi', 'eyeliner', 'maskara', 'mascara',
        'far', 'eyeshadow', 'palet', 'palette', 'highlighter', 'kontür', 'contour',
        'dudak parlatıcı', 'dudak parlatıcı', 'lip gloss', 'lipstick', 'lip balm',
        'primer', 'primer', 'makeup base', 'makyaj bazı', 'makyaj bazi', 'setting spray'
      ],
      'Cilt & Yüz Bakımı': [
        'nemlendirici', 'moisturizer', 'krem', 'cream', 'yüz kremi', 'yuz kremi', 'face cream',
        'güneş kremi', 'gunes kremi', 'sunscreen', 'spf', 'spf 50', 'spf 30', 'serum', 'face serum',
        'tonik', 'toner', 'temizleme', 'cleanser', 'yüz temizleme', 'yuz temizleme', 'face wash',
        'peeling', 'exfoliator', 'maske', 'mask', 'yüz maskesi', 'yuz maskesi', 'face mask',
        'göz kremi', 'goz kremi', 'eye cream', 'anti aging', 'anti-aging', 'yaşlanma karşıtı',
        'yaslanma karsiti', 'retinol', 'vitamin c', 'c vitamini', 'hyaluronic acid', 'hyaluronik asit',
        'prezervatif', 'prezervatifler', 'condom', 'durex', 'okey', 'cinsel sağlık', 'cinsel saglik'
      ],
      'Saç Bakımı': [
        'şampuan', 'sampuan', 'shampoo', 'saç kremi', 'sac kremi', 'conditioner', 'bakım kremi',
        'bakim kremi', 'hair mask', 'saç maskesi', 'sac maskesi', 'saç spreyi', 'sac spreyi',
        'hair spray', 'jöle', 'jole', 'gel', 'wax', 'pomade', 'saç fırçası', 'sac fircasi',
        'hair brush', 'tarak', 'comb', 'saç kurutma', 'sac kurutma', 'hair dryer', 'fön makinesi',
        'fon makinesi', 'düzleştirici', 'duzlestirici', 'flat iron', 'maşa', 'curling iron',
        'saç boyası', 'sac boyasi', 'hair dye', 'renk açıcı', 'renk acici', 'hair bleach'
      ],
      'Ağız & Diş Bakımı': [
        'diş fırçası', 'dis fircasi', 'toothbrush', 'elektrikli diş fırçası', 'elektrikli dis fircasi',
        'electric toothbrush', 'oral-b', 'philips sonicare', 'diş macunu', 'dis macunu', 'toothpaste',
        'ağız bakım suyu', 'agiz bakim suyu', 'mouthwash', 'gargara', 'diş ipi', 'dis ipi',
        'dental floss', 'diş beyazlatıcı', 'dis beyazlatici', 'teeth whitening', 'ağız spreyi', 'agiz spreyi',
        'mouth spray', 'diş fırçası başlığı', 'toothbrush head'
      ],
    },
    'spor_outdoor': {
      'Spor Giyim & Ayakkabı': [
        'spor ayakkabı', 'spor ayakkabi', 'sneakers', 'sports shoes', 'koşu ayakkabı', 'kosu ayakkabi',
        'running shoes', 'fitness', 'egzersiz', 'exercise', 'spor kıyafet', 'spor kiyafet', 'sportswear',
        'eşofman', 'esofman', 'tracksuit', 'spor giyim', 'erkek spor giyim', 'kadin spor giyim',
        'spor çorap', 'spor corap', 'sports socks', 'spor çanta', 'spor canta', 'gym bag',
        'spor tişört', 'spor tisort', 'spor şort', 'spor sort', 'under armour', 'nike', 'adidas',
        'puma', 'reebok', 'new balance', 'columbia', 'the north face', 'patagonia', 'lululemon',
        'dambıl', 'dumbbell', 'halter', 'barbell', 'ağırlık', 'agirlik', 'weight', 'kettlebell'
      ],
      'Fitness & Kondisyon': [
        'fitness', 'koşu bandı', 'kosu bandi', 'treadmill', 'bisiklet', 'bike', 'exercise bike',
        'eliptik', 'elliptical', 'dambıl', 'dumbbell', 'halter', 'barbell', 'ağırlık seti',
        'agirlik seti', 'weight set', 'fitness ekipman', 'fitness equipment', 'ev spor aleti',
        'ev spor aleti', 'home gym', 'bench', 'bench press', 'smith machine', 'cable machine',
        'pull up bar', 'barfiks', 'resistance band', 'direnç bandı', 'direnc bandi',
        'mat', 'yoga matı', 'yoga mati', 'yoga mat', 'pilates matı', 'pilates mati', 'pilates mat',
        'egzersiz matı', 'egzersiz mati'
      ],
      'Kamp & Doğa Malzemeleri': [
        'çadır', 'cadir', 'tent', 'uyku tulumu', 'uyku tulumu', 'sleeping bag', 'mat', 'sleeping mat',
        'kamp', 'camping', 'kamp malzemesi', 'kamp malzemesi', 'camping gear', 'kamp çantası',
        'kamp cantasi', 'backpack', 'kamp sandalyesi', 'camping chair', 'kamp masası', 'camping table',
        'fener', 'flashlight', 'torch', 'kafa lambası', 'kafa lambasi', 'headlamp', 'termos',
        'thermos', 'kamp ocağı', 'kamp ocagi', 'camping stove', 'tüp', 'tup', 'gas canister',
        'doğa yürüyüşü', 'doga yuruyusu', 'hiking', 'trekking', 'trekking pole', 'yürüyüş batonu',
        'stanley'
      ],
      'Bisiklet & Ekipmanları': [
        'bisiklet', 'bicycle', 'bike', 'mountain bike', 'mtb', 'şehir bisikleti', 'sehir bisikleti',
        'city bike', 'elektrikli bisiklet', 'elektrikli bisiklet', 'e-bike', 'electric bike',
        'bisiklet kaskı', 'bisiklet kaski', 'bike helmet', 'bisiklet aksesuar', 'bike accessory',
        'bisiklet pompası', 'bisiklet pompasi', 'bike pump', 'bisiklet kilidi', 'bike lock',
        'bisiklet gözlüğü', 'bike glasses', 'bisiklet eldiveni', 'bike gloves', 'bisiklet çantası', 'bike bag'
      ],
      'Bireysel & Takım Sporları': [
        'futbol', 'basketbol', 'voleybol', 'tenis', 'badminton', 'boks', 'masa tenisi', 'yüzme', 'yuzme',
        'mayo', 'bikinisi', 'bikini', 'futbol topu', 'basketbol topu', 'raket', 'boks eldiveni',
        'tenis raketi', 'tenis raketi', 'badminton raketi', 'badminton raketi', 'squash raketi',
        'wilson', 'babolat', 'head raket', 'yonex', 'dunlop',
        'yoga matı', 'yoga mati', 'pilates topu', 'direnç bandı', 'direnc bandi', 'yüzme gözlüğü',
        'yuzme gozluk', 'bone', 'krampon', 'tekvando', 'karate', 'koruyucu ekipman'
      ]
    },
    'supermarket': {
      'Gıda Ürünleri': [
        'gıda', 'gida', 'food', 'yiyecek', 'içecek', 'icecek', 'drink', 'beverage', 'atıştırmalık',
        'atistirmalik', 'snack', 'çikolata', 'cikolata', 'chocolate', 'bisküvi', 'bisküvi', 'biscuit',
        'cips', 'chips', 'kraker', 'cracker', 'konserve', 'canned', 'makarna', 'pasta', 'pirinç',
        'pirinc', 'rice', 'bulgur', 'bakliyat', 'legume', 'zeytinyağı', 'zeytinyagi', 'olive oil',
        'ayçiçek yağı', 'aycicek yagi', 'sunflower oil', 'salça', 'salca', 'tomato paste', 'baharat',
        'spice', 'çay', 'cay', 'tea', 'kahve', 'coffee', 'süt', 'sut', 'milk', 'yoğurt', 'yogurt',
        'peynir', 'cheese', 'yumurta', 'egg', 'et', 'meat', 'tavuk', 'chicken', 'balık', 'balik', 'fish'
      ],
      'Deterjan & Temizlik': [
        'deterjan', 'detergent', 'çamaşır deterjanı', 'camasir deterjani', 'laundry detergent',
        'bulaşık deterjanı', 'bulasik deterjani', 'dish soap', 'yumuşatıcı', 'yumusatici', 'fabric softener',
        'temizlik', 'cleaning', 'cam temizleyici', 'cam temizleyici', 'glass cleaner', 'yüzey temizleyici',
        'yuzey temizleyici', 'surface cleaner', 'banyo temizleyici', 'bathroom cleaner',
        'tuvalet temizleyici', 'toilet cleaner', 'sıvı sabun', 'sivi sabun', 'liquid soap',
        'el sabunu', 'hand soap', 'bulaşık süngeri', 'bulasik sungeri', 'dish sponge',
        'temizlik bezi', 'cleaning cloth', 'mop', 'paspas', 'floor mop'
      ],
      'Kağıt Ürünleri': [
        'tuvalet kağıdı', 'tuvalet kagidi', 'toilet paper', 'peçete', 'pecete', 'tissue', 'napkin',
        'kağıt havlu', 'kagit havlu', 'paper towel', 'mendil', 'handkerchief', 'hijyenik ped',
        'hijyenik ped', 'sanitary pad', 'bebek bezi', 'diaper', 'ıslak mendil', 'islak mendil', 'wet wipes',
        'alüminyum folyo', 'aluminyum folyo', 'aluminum foil', 'streç film', 'stretch film', 'cling film',
        'buzdolabı poşeti', 'buzdolabi poseti', 'freezer bag', 'çöp poşeti', 'cop poseti', 'garbage bag'
      ],
      'Kedi & Köpek Ürünleri': [
        'kedi maması', 'kedi mamasi', 'cat food', 'köpek maması', 'kopek mamasi', 'dog food',
        'kuru mama', 'dry food', 'yaş mama', 'yas mama', 'wet food', 'konserve', 'canned food',
        'kedi kumu', 'kedi kumu', 'cat litter', 'kum kabı', 'litter box', 'oyuncak', 'toy',
        'tasma', 'leash', 'kemer', 'collar', 'köpek tasması', 'kopek tasmasi', 'dog collar',
        'kedi tırmalama', 'kedi tirmalama', 'scratching post', 'köpek yatağı', 'kopek yatagi', 'dog bed',
        'kedi yatağı', 'kedi yatagi', 'cat bed', 'pet carrier', 'pet taşıyıcı', 'pet tasiyici'
      ],
    },
    'yapi_oto': {
      'Elektrikli Aletler, Hırdavat & İş Güvenliği': [
        'matkap', 'drill', 'vidalama', 'screwdriver', 'tornavida', 'screwdriver', 'anahtar', 'wrench',
        'pense', 'pliers', 'çekiç', 'cekic', 'hammer', 'keski', 'chisel', 'testere', 'saw',
        'elektrikli alet', 'power tool', 'akülü matkap', 'akulu matkap', 'cordless drill',
        'şarjlı matkap', 'sarjli matkap', 'hırdavat', 'hirdavat', 'hardware', 'vida', 'screw',
        'çivi', 'civi', 'nail', 'dübel', 'dubel', 'dowel', 'zımba', 'zimba', 'stapler', 'zımba teli',
        'zimba teli', 'staple', 'angle grinder', 'açılı taşlama', 'acili taslama', 'circular saw', 'daire testere',
        'iş eldiveni', 'is eldiveni', 'baret', 'güvenlik ayakkabısı', 'guvenlik ayakkabisi', 'iş ayakkabısı',
        'is ayakkabisi', 'güvenlik yeleği', 'guvenlik yelegi', 'koruyucu gözlük', 'koruyucu gozluk'
      ],
      'Oto Aksesuar & Bakım': [
        'oto', 'araba', 'car', 'araç', 'vehicle', 'oto aksesuar', 'car accessory', 'araç aksesuar',
        'koltuk kılıfı', 'koltuk kilifi', 'seat cover', 'paspas', 'floor mat', 'araç paspası',
        'arac paspasi', 'car mat', 'araç temizlik', 'arac temizlik', 'car cleaning', 'cam suyu',
        'windshield washer fluid', 'motor yağı', 'motor yagi', 'engine oil', 'fren balata',
        'brake pad', 'lastik', 'tire', 'jant', 'rim', 'wheel', 'araç bakım', 'arac bakim', 'car maintenance',
        'oto bakım', 'car service', 'araç kokusu', 'car air freshener', 'araç şarj', 'car charger'
      ],
      'Banyo, Tesisat & Yapı': [
        'banyo', 'bathroom', 'lavabo', 'sink', 'klozet', 'toilet', 'duşakabin', 'dusakabin', 'shower cabin',
        'küvet', 'kuvet', 'bathtub', 'musluk', 'faucet', 'batarya', 'tap', 'duş başlığı', 'dus basligi',
        'shower head', 'banyo aksesuar', 'bathroom accessory', 'banyo dolabı', 'bathroom cabinet',
        'ayna', 'mirror', 'banyo aynası', 'bathroom mirror', 'havlu askısı', 'towel rack',
        'sabunluk', 'soap dispenser', 'diş fırçası kabı', 'dis fircasi kabi', 'toothbrush holder',
        'duş perdesi', 'dus perdesi', 'shower curtain', 'banyo paspası', 'bath mat',
        'boya', 'tavan boyası', 'tavan boyasi', 'sprey boya', 'plastik boya', 'derz dolgu', 'derz',
        'seramik', 'fayans', 'yalıtım bandı', 'yalitim bandi', 'silikon', 'köpük', 'kopuk', 'alçı', 'alci'
      ],
      'Bahçe Malzemeleri': [
        'bahçe', 'bahce', 'garden', 'çim biçme', 'cim bicme', 'lawn mowing', 'çim biçme makinesi',
        'cim bicme makinesi', 'lawn mower', 'tırpan', 'tirpan', 'weed trimmer', 'budama makası',
        'budama makasi', 'pruning shears', 'bahçe hortumu', 'bahce hortumu', 'garden hose',
        'sulama', 'irrigation', 'sulama sistemi', 'irrigation system', 'gübre', 'gubre', 'fertilizer',
        'toprak', 'soil', 'saksı', 'saksi', 'pot', 'plant pot', 'bitki', 'plant', 'tohum', 'seed',
        'fide', 'seedling', 'bahçe aleti', 'bahce aleti', 'garden tool', 'tırpan', 'sprinkler', 'fıskiye'
      ],
    },
    'kitap_hobi': {
      'Kitap & Dergi': [
        'kitap', 'book', 'roman', 'novel', 'hikaye', 'story', 'ders kitabı', 'ders kitabi', 'textbook',
        'test kitabı', 'test kitabi', 'test book', 'yaprak test', 'worksheet', 'ders notu', 'ders notu',
        'lecture notes', 'ders anlatım', 'ders anlatim', 'edebiyat', 'literature', 'tarih', 'history',
        'felsefe', 'philosophy', 'bilim', 'science', 'dergi', 'magazine', 'magazin', 'gazete', 'newspaper',
        'manga', 'çizgi roman', 'cizgi roman', 'comic', 'graphic novel', 'çocuk kitabı', 'children book'
      ],
      'Müzik Enstrümanları': [
        'gitar', 'guitar', 'akustik gitar', 'acoustic guitar', 'elektro gitar', 'electric guitar',
        'piyano', 'piano', 'keman', 'violin', 'bağlama', 'baglama', 'saz', 'davul', 'drum', 'bateri',
        'drum set', 'flüt', 'flut', 'flute', 'klarnet', 'clarinet', 'saksafon', 'saxophone', 'trompet',
        'trumpet', 'müzik aleti', 'muzik aleti', 'musical instrument', 'enstrüman', 'enstruman',
        'gitar teli', 'guitar string', 'akort aleti', 'tuner', 'metronom', 'metronome', 'mikrofon',
        'microphone', 'hoparlör', 'speaker', 'amplifier', 'amp', 'amplifikatör', 'amplifikator',
        'plak', 'plaklar', 'vinyl', 'lp', 'cd'
      ],
      'Oyun Konsolları & Video Oyunları': [
        'playstation', 'ps4', 'ps5', 'xbox', 'xbox one', 'xbox series', 'nintendo', 'switch',
        'nintendo switch', 'oyun konsolu', 'oyun konsolu', 'game console', 'konsol', 'console',
        'oyun', 'game', 'video oyun', 'video game', 'oyun kumandası', 'oyun kumandasi', 'game controller',
        'joystick', 'oyun koltuğu', 'oyun koltugu', 'gaming chair', 'gaming', 'oyun bilgisayarı',
        'oyun bilgisayari', 'gaming pc', 'gaming laptop', 'gaming mouse', 'gaming klavye', 'gaming keyboard',
        'gaming headset', 'oyun kulaklığı', 'oyun kulakligi', 'gaming monitor', 'oyun monitörü'
      ],
      'Hobi & Sanat Malzemeleri': [
        'hobi', 'hobby', 'sanat', 'art', 'resim', 'painting', 'boya', 'paint', 'fırça', 'firca', 'brush',
        'tuval', 'canvas', 'palet', 'palette', 'kalem', 'pencil', 'kurşun kalem', 'kursun kalem',
        'pencil', 'pastel', 'pastel', 'suluboya', 'watercolor', 'akrilik', 'acrylic', 'yağlı boya',
        'yagli boya', 'oil paint', 'guaj', 'gouache', 'maket', 'model', 'model kit', 'el işi', 'el isi', 'handicraft',
        'dikiş', 'dikis', 'sewing', 'nakış', 'nakis', 'embroidery', 'örgü', 'orgu', 'knitting',
        'tığ', 'tig', 'crochet hook', 'şiş', 'sis', 'knitting needle', 'iplik', 'yarn', 'thread',
        'kumaş', 'fabric', 'cloth', 'scissors', 'makas', 'ruler', 'cetvel'
      ],
      'Kutu Oyunları & Oyuncaklar': [
        'kutu oyunu', 'board game', 'monopoly', 'catan', 'tabu', 'jenga', 'lego', 'oyuncak', 'toy',
        'oyuncak araba', 'bebek oyuncak', 'barbie', 'hot wheels', 'puzzle', 'yapboz', 'maket',
        'oyuncak bebek', 'aksiyon figür', 'figur', 'oyun hamuru', 'oyun hamurları', 'oyun hamurlari', 'play-doh', 'play doh'
      ]
    },
    'dijital_hizmetler': {
      'Abonelik & Yazılım': [
        'abonelik', 'subscription', 'netflix', 'spotify', 'youtube premium', 'premium', 'amazon prime', 'prime video',
        'disney+', 'disney plus', 'blutv', 'gain', 'exxen', 'vpn', 'nordvpn', 'expressvpn', 'antivirüs', 'antivirus',
        'kaspersky', 'norton', 'office 365', 'microsoft office', 'windows key', 'lisans', 'yazılım', 'yazilim',
        'hosting', 'domain', 'bulut depolama', 'cloud storage', 'google one', 'icloud'
      ],
      'Yemek & Restoran': [
        'yemeksepeti', 'getiryemek', 'trendyol yemek', 'dominos', 'pizza', 'burger king', 'mcdonalds',
        'tıkla gelsin', 'tikla gelsin', 'restoran', 'cafe', 'kahve dünyası', 'kahve dunyasi', 'starbucks',
        '1 alana 1 bedava', 'menü', 'menu', 'lahmacun', 'döner', 'doner', 'kebap', 'köfteci yusuf', 'kofteci yusuf'
      ],
      'Seyahat & Eğlence': [
        'uçak bileti', 'ucak bileti', 'otobüs bileti', 'otobus bileti', 'otel', 'hotel', 'airbnb', 'rezervasyon',
        'tatil', 'tur', 'seyahat', 'flight ticket', 'sinema bileti', 'sinema', 'konser bileti', 'konser',
        'tiyatro', 'etkinlik', 'biletix', 'bubilet', 'kamil koç', 'kamil koc', 'metro turizm', 'pegasus', 'thy'
      ],
      'Dijital Kod & Oyun Pinleri': [
        'steam', 'steam cüzdan', 'steam cuzdan', 'steam key', 'valorant', 'vp', 'valorant points',
        'pubg uc', 'pubg mobile uc', 'roblox', 'robux', 'google play kodu', 'itunes kartı', 'itunes karti',
        'playstation plus', 'ps plus', 'xbox game pass', 'game pass', 'cüzdan kodu', 'cuzdan kodu',
        'epin', 'e-pin', 'razer gold', 'lol rp', 'league of legends rp'
      ]
    },
    'finans_kampanyalar': {
      'Banka Kampanyaları': [
        'banka', 'kredi kartı', 'kredi karti', 'kampanya', 'chip-para', 'chippara', 'bonus', 'parafpara',
        'maxipuan', 'worldpuan', 'hediye para', 'nakit iade', 'cashback', 'nays', 'akbank', 'garanti',
        'is bankasi', 'iş bankası', 'yapi kredi', 'yapı kredi', 'qnb', 'finansbank', 'teb', 'vakifbank',
        'halkbank', 'ziraat', 'taksit', 'faizsiz', 'masrafsız', 'masrafsiz'
      ],
      'Yatırım & Değerli Metaller': [
        'altın', 'altin', 'gold', 'gram altın', 'gram altin', 'çeyrek altın', 'ceyrek altin', 'yarım altın',
        'yarim altin', 'tam altın', 'tam altin', 'cumhuriyet altını', 'cumhuriyet altini', 'ata altın',
        'ata altin', 'has altın', 'has altin', 'külçe altın', 'kulce altin', 'ayar altın', 'ayar altin',
        '24 ayar', '22 ayar', 'gümüş', 'gumus', 'silver', 'külçe gümüş', 'kulce gumus', 'sarrafiye',
        'ziynet'
      ]
    }
  };

  // Güçlü anahtar kelimeler (Doğrudan kategori sinyali verenler, +10.0 puan)
  static const List<String> _strongKeywords = [
    'deterjan', 'matkap', 'ruj', 'fondoten', 'maskara', 'parfum', 'sampuan', 'ütü', 'utu',
    'süpürge', 'supurge', 'buzdolabı', 'buzdolabi', 'biberon', 'emzik', 'puset', 'mama',
    'kitap', 'roman', 'manga', 'gitar', 'piyano', 'krampon', 'dambıl', 'dambil', 'çadır', 'cadir',
    'lastik', 'oto', 'motosiklet', 'pantolon', 'elbise', 'etek', 'bluz', 'cüzdan', 'cuzdan',
    'gardrop', 'gardırop', 'kanepe', 'koltuk', 'çarşaf', 'carsaf', 'yorgan', 'yastık', 'yastik',
    'tava', 'tencere', 'akülü', 'akulu', 'matkap', 'testere', 'kedi maması', 'kedi mamasi',
    'köpek maması', 'kopek mamasi', 'kedi kumu', 'kedi kumu',
    'netflix', 'spotify', 'youtube premium', 'yemeksepeti', 'getiryemek', 'steam', 'valorant',
    'nays', 'chip-para', 'chippara', 'faizsiz', 'gram altin', 'ceyrek altin', 'külçe altın',
    'kulce altin', 'ucak bileti', 'otobüs bileti', 'tıraş makinesi', 'tiras makinesi', 'epilatör',
    'epilator', 'saç kurutma', 'sac kurutma', 'fön makinesi', 'fon makinesi', 'düzleştirici',
    'duzlestirici', 'akıllı priz', 'akilli priz', 'akıllı ampul', 'akilli ampul', 'lego', 'emzirme',
    'monopoly', 'tabu', 'jenga', 'catan', 'hava temizleyici', 'vantilatör', 'vantilator', 'prezervatif', 'durex',
    'aptamil', 'devam sütü', 'devam sutu', 'bebek maması', 'bebek mamasi', 'modem', 'router', 'tp-link', 'keenetic', 'plak', 'vinyl', 'oyun hamuru', 'oyun hamurlari'
  ];

  // Zayıf anahtar kelimeler (Markalar, genel belirteçler, +2.0 puan)
  static const List<String> _weakKeywords = [
    'samsung', 'apple', 'nike', 'adidas', 'puma', 'erkek', 'kadin', 'bayan', 'cocuk', 'çocuk',
    'bebek', 'baby', 'spor', 'hobi', 'aksesuar', 'orijinal', 'original', 'kablo', 'kılıf', 'kilif',
    'askı', 'aski', 'cam', 'stand', 'tutucu', 'set', 'kutu', 'paket', 'kampanya', 'indirim', 'oyun'
  ];

  static double _getKeywordWeight(String keyword) {
    if (_strongKeywords.contains(keyword)) return 10.0;
    if (_weakKeywords.contains(keyword)) return 2.0;
    return 5.0; // Varsayılan ağırlık
  }

  /// Metinden kategori ve alt kategori tespit eder
  /// 
  /// [text] Tespit edilecek metin (başlık, açıklama vb.)
  /// 
  /// Returns: Map with 'categoryId' and 'subCategory' keys, or null if no match
  static Map<String, String?>? detectCategory(String text) {
    if (text.isEmpty) return null;

    // Metni küçük harfe çevir ve Türkçe karakterleri normalize et
    final normalizedText = _normalizeText(text.toLowerCase());
    final originalText = text.toLowerCase();
    
    // Metni kelimelere ayır (Performans için tek bir kez ayırıyoruz)
    final words = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));
    final originalWords = originalText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));

    _log('🔍 Kategori tespiti başlatılıyor: "$text"');
    _log('📝 Normalize edilmiş metin: "$normalizedText"');

    // Her kategori için skor hesapla
    final categoryScores = <String, Map<String, double>>{};

    for (final categoryEntry in _categoryKeywords.entries) {
      final categoryId = categoryEntry.key;
      final subCategories = categoryEntry.value;
      categoryScores[categoryId] = {};

      for (final subCategoryEntry in subCategories.entries) {
        final subCategory = subCategoryEntry.key;
        final keywords = subCategoryEntry.value;

        // Her keyword için eşleşme kontrolü
        double score = 0;
        for (final keyword in keywords) {
          final normalizedKeyword = _normalizeText(keyword.toLowerCase());
          final originalKeyword = keyword.toLowerCase();
          
          // 1. Öbek/Phrase (N-Gram) Eşleşmesi: Kelime boşluk içeriyorsa bütünsel kontrol et (Çok güçlü sinyal, +12.0)
          if (normalizedKeyword.contains(' ')) {
            bool matchesPhrase = normalizedText.contains(normalizedKeyword) || originalText.contains(originalKeyword);
            
            // Sonek kaynaklı (plural/possessive) farkları yakalamak için gövde karşılaştırması
            if (!matchesPhrase) {
              final keywordWords = normalizedKeyword.split(' ');
              for (int i = 0; i <= words.length - keywordWords.length; i++) {
                bool sequenceMatches = true;
                for (int j = 0; j < keywordWords.length; j++) {
                  final textWord = words[i + j];
                  final keyWord = keywordWords[j];
                  if (_stem(textWord) != _stem(keyWord)) {
                    sequenceMatches = false;
                    break;
                  }
                }
                if (sequenceMatches) {
                  matchesPhrase = true;
                  break;
                }
              }
            }

            if (matchesPhrase) {
              score += 12.0;
              _log('   🔥 Tam öbek (N-Gram) eşleşmesi: "$keyword" (+12.0)');
              continue; // Diğer kelime bazlı eşleşmelere bakmaya gerek yok
            }
          }

          final double weight = _getKeywordWeight(normalizedKeyword);

          // 2. Tam kelime eşleşmesi
          bool exactWordMatch = false;
          for (int i = 0; i < words.length; i++) {
            final word = words[i];
            final originalWord = originalWords.length > i ? originalWords[i] : '';
            
            if (word == normalizedKeyword || 
                originalWord == originalKeyword ||
                _stem(word) == _stem(normalizedKeyword)) {
              score += weight;
              exactWordMatch = true;
              _log('   ✅ Tam kelime eşleşmesi: "$keyword" (+$weight)');
              break;
            }
          }
          
          // 3. Alt metin eşleşmesi (tam kelime eşleşmediyse)
          if (!exactWordMatch) {
            bool isSubMatch = false;
            for (final word in words) {
              if (word.startsWith(normalizedKeyword)) {
                if (normalizedKeyword.length >= 4 || (word.length - normalizedKeyword.length) <= 3) {
                  isSubMatch = true;
                  break;
                }
              }
            }
            if (isSubMatch) {
              final double partialWeight = weight * 0.6; // Kelime ağırlığının %60'ı kadar
              score += partialWeight;
              _log('   ✅ Alt metin eşleşmesi: "$keyword" (+$partialWeight)');
            }
          }
          
          // 4. Kelime benzerlik eşleşmesi (sadece zayıf sinyaller için bakma ve boşluk içermeyen anahtar kelimeler)
          if (!exactWordMatch && weight > 2.0 && !normalizedKeyword.contains(' ')) {
            for (final word in words) {
              if (word.length >= 3) {
                if (normalizedKeyword.contains(word) || word.contains(normalizedKeyword)) {
                  score += 1.0;
                }
              }
            }
          }
        }

        if (score > 0) {
          categoryScores[categoryId]![subCategory] = score;
          _log('   📊 $categoryId > $subCategory: $score puan');
        }
      }
    }

    // En yüksek skorlu kategori ve alt kategoriyi bul
    String? bestCategoryId;
    String? bestSubCategory;
    double bestScore = 0;

    for (final categoryEntry in categoryScores.entries) {
      for (final subCategoryEntry in categoryEntry.value.entries) {
        if (subCategoryEntry.value > bestScore) {
          bestScore = subCategoryEntry.value;
          bestCategoryId = categoryEntry.key;
          bestSubCategory = subCategoryEntry.key;
        }
      }
    }

    // Minimum skor eşiği
    final minScore = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+')).length == 1 ? 1.5 : 2.0;
    if (bestScore < minScore) {
      _log('❌ Skor çok düşük: $bestScore (minimum: $minScore)');
      return null;
    }

    // 5. Negatif İstisnalar (Exclusions) Post-Processing
    final refinedResult = _applyNegativeExclusions(normalizedText, bestCategoryId, bestSubCategory);
    bestCategoryId = refinedResult['categoryId'];
    bestSubCategory = refinedResult['subCategory'];

    _log('✅ Nihai Eşleşme (İstisnalar Sonrası): $bestCategoryId > $bestSubCategory (skor: $bestScore)');

    return {
      'categoryId': bestCategoryId,
      'subCategory': bestSubCategory,
    };
  }

  /// Negatif kurallar ve çapraz eşleşmeleri düzelten istisna yöneticisi
  static Map<String, String?> _applyNegativeExclusions(String normalizedText, String? categoryId, String? subCategory) {
    String? finalCategoryId = categoryId;
    String? finalSubCategory = subCategory;

    // 1. Yastık/Yorgan Kılıfı (Ev Tekstili olmalı, Telefon Kılıfı / Elektronik değil)
    if (normalizedText.contains('kilif')) {
      final isBedding = normalizedText.contains('yastik') ||
                        normalizedText.contains('yorgan') ||
                        normalizedText.contains('yatak') ||
                        normalizedText.contains('kirlent') ||
                        normalizedText.contains('nevresim');
      if (isBedding) {
        finalCategoryId = 'ev_yasam';
        finalSubCategory = 'Ev Tekstili';
      }
    }

    // 2. Bebek Deterjanı, Yumuşatıcı, Sabun (Süpermarket olmalı, Anne Bebek değil)
    if (normalizedText.contains('bebek') || normalizedText.contains('baby')) {
      final isDetergent = normalizedText.contains('deterjan') ||
                          normalizedText.contains('yumusatici') ||
                          normalizedText.contains('sabun') ||
                          normalizedText.contains('temizleyici');
      if (isDetergent) {
        finalCategoryId = 'supermarket';
        finalSubCategory = 'Deterjan & Temizlik';
      }
    }

    // 3. Bebek Şampuanı, Bebek Yağı, Bebek Kremi (Kozmetik olmalı, Anne Bebek değil)
    if (normalizedText.contains('bebek') || normalizedText.contains('baby')) {
      final isCosmetic = normalizedText.contains('sampuan') ||
                         normalizedText.contains('yag') ||
                         normalizedText.contains('krem') ||
                         normalizedText.contains('losyon') ||
                         normalizedText.contains('macun');
      if (isCosmetic) {
        finalCategoryId = 'kozmetik';
        finalSubCategory = normalizedText.contains('sampuan') ? 'Saç Bakımı' : 'Cilt & Yüz Bakımı';
      }
    }

    // 4. Spor Kıyafet / Spor Ayakkabı - sadece genel moda bağlamında moda'ya git
    // Spor markası veya 'spor giyim' bağlamı varsa spor_outdoor olarak bırak
    if (normalizedText.contains('spor') && finalCategoryId == 'spor_outdoor') {
      final isSportsContext = normalizedText.contains('spor giyim') ||
                              normalizedText.contains('under armour') ||
                              normalizedText.contains('nike') ||
                              normalizedText.contains('adidas') ||
                              normalizedText.contains('puma') ||
                              normalizedText.contains('reebok') ||
                              normalizedText.contains('decathlon') ||
                              normalizedText.contains('columbia') ||
                              normalizedText.contains('erkek spor') ||
                              normalizedText.contains('kadin spor') ||
                              normalizedText.contains('spor tisort') ||
                              normalizedText.contains('spor sort');
      // spor_outdoor'da kalıyorsa dokunma
      if (!isSportsContext) {
        final isClothingOrShoe = normalizedText.contains('ayakkabi') ||
                                normalizedText.contains('tisort') ||
                                normalizedText.contains('t-shirt') ||
                                normalizedText.contains('tshirt') ||
                                normalizedText.contains('sort') ||
                                normalizedText.contains('tayt') ||
                                normalizedText.contains('mont') ||
                                normalizedText.contains('esofman') ||
                                normalizedText.contains('yelek') ||
                                normalizedText.contains('corap') ||
                                normalizedText.contains('canta') ||
                                normalizedText.contains('ceket');
        if (isClothingOrShoe) {
          finalCategoryId = 'moda';
          finalSubCategory = normalizedText.contains('ayakkabi') ? 'Ayakkabı & Çanta' : 'Kadın Giyim';
        }
      }
    }

    // 5. Akıllı Saat / Smartwatch (Elektronik olmalı, Moda'nın klasik Kol Saatleri değil)
    if (normalizedText.contains('akilli saat') ||
        normalizedText.contains('smartwatch') ||
        normalizedText.contains('akilli bileklik') ||
        normalizedText.contains('watch gt') ||
        normalizedText.contains('galaxy watch') ||
        normalizedText.contains('apple watch') ||
        normalizedText.contains('garmin') ||
        (normalizedText.contains('watch') && normalizedText.contains('huawei')) ||
        (normalizedText.contains('watch') && normalizedText.contains('samsung')) ||
        (normalizedText.contains('watch') && normalizedText.contains('apple'))) {
      finalCategoryId = 'elektronik';
      finalSubCategory = 'Telefon & Aksesuarları';
    }

    // 6. Bebek kelimesi geçip giyim kelimeleri geçmiyorsa Çocuk Giyim yerine Anne Bebek olmalı
    if (finalCategoryId == 'moda' && finalSubCategory == 'Çocuk Giyim') {
      final hasBaby = normalizedText.contains('bebek') || normalizedText.contains('baby');
      if (hasBaby) {
        final hasClothing = normalizedText.contains('giyim') ||
                            normalizedText.contains('tulum') ||
                            normalizedText.contains('elbise') ||
                            normalizedText.contains('pantolon') ||
                            normalizedText.contains('tisort') ||
                            normalizedText.contains('t-shirt') ||
                            normalizedText.contains('tshirt') ||
                            normalizedText.contains('corap') ||
                            normalizedText.contains('ayakkabi') ||
                            normalizedText.contains('patik') ||
                            normalizedText.contains('mont') ||
                            normalizedText.contains('yelek') ||
                            normalizedText.contains('ceket') ||
                            normalizedText.contains('bere') ||
                            normalizedText.contains('sapka') ||
                            normalizedText.contains('takim');
        if (!hasClothing) {
          finalCategoryId = 'anne_bebek';
          finalSubCategory = 'Bebek Odası & Güvenlik';
        }
      }
    }

    // 7. Yatırım Altın vs. Takı/Mücevher Ayrımı
    // Eğer başlıkta kolye, bileklik gibi takı ifadeleri geçiyorsa Moda -> Saat, Aksesuar & Takı olmalı
    final words = normalizedText.split(RegExp(r'[^\w]+'));
    final isJewelry = normalizedText.contains('kolye') ||
                      normalizedText.contains('bileklik') ||
                      normalizedText.contains('kupe') ||
                      normalizedText.contains('yuzuk') ||
                      words.contains('taki') ||
                      words.contains('takilar') ||
                      normalizedText.contains('zincir') ||
                      normalizedText.contains('halka') ||
                      normalizedText.contains('tasli') ||
                      normalizedText.contains('pirlanta') ||
                      normalizedText.contains('tektas');
                      
    if (isJewelry) {
      // Akıllı saat / bileklik bağlamı varsa jewelry kuralı uygulanmaz
      final isSmartWearable = normalizedText.contains('akilli saat') ||
                              normalizedText.contains('akilli bileklik') ||
                              normalizedText.contains('smartwatch') ||
                              normalizedText.contains('watch gt') ||
                              (normalizedText.contains('watch') && (
                                normalizedText.contains('huawei') ||
                                normalizedText.contains('samsung') ||
                                normalizedText.contains('apple') ||
                                normalizedText.contains('garmin')));
      if (!isSmartWearable) {
        finalCategoryId = 'moda';
        finalSubCategory = 'Saat, Aksesuar & Takı';
      }
    } else {
      // Eğer takı değilse ve gram altın, çeyrek altın gibi kelimeler geçiyorsa Finans -> Yatırım olmalı
      final isInvestmentGold = normalizedText.contains('gram altin') ||
                               normalizedText.contains('ceyrek altin') ||
                               normalizedText.contains('yarim altin') ||
                               normalizedText.contains('tam altin') ||
                               normalizedText.contains('cumhuriyet altin') ||
                               normalizedText.contains('ata altin') ||
                               normalizedText.contains('has altin') ||
                               normalizedText.contains('kulce altin') ||
                               normalizedText.contains('külçe altin') ||
                               normalizedText.contains('24 ayar') ||
                               normalizedText.contains('22 ayar') ||
                               normalizedText.contains('kulce gumus') ||
                               normalizedText.contains('külçe gümüş');
                               
      if (isInvestmentGold) {
        finalCategoryId = 'finans_kampanyalar';
        finalSubCategory = 'Yatırım & Değerli Metaller';
      }
    }

    // 7b. Yatak / Yorgan / Mobilya vs. Yapı (Ortopedik yatak, yaylı yatak → ev_yasam)
    if (finalCategoryId == 'yapi_oto') {
      final isBeddingOrFurniture = normalizedText.contains('yatak') ||
                                    normalizedText.contains('yorgan') ||
                                    normalizedText.contains('nevresim') ||
                                    normalizedText.contains('carsaf') ||
                                    normalizedText.contains('çarşaf') ||
                                    normalizedText.contains('yastik') ||
                                    normalizedText.contains('yastık') ||
                                    normalizedText.contains('koltuk takimi') ||
                                    normalizedText.contains('koltuk takımı') ||
                                    normalizedText.contains('gardirop') ||
                                    normalizedText.contains('gardırop') ||
                                    normalizedText.contains('dolap') ||
                                    normalizedText.contains('ortopedik');
      if (isBeddingOrFurniture) {
        finalCategoryId = 'ev_yasam';
        finalSubCategory = 'Mobilya';
      }
    }

    // 8. Yazılım / Lisans / Kurulum Paketleri (Dijital Hizmetler olmalı, Elektronik veya Kitap/Hobi değil)
    final isSoftware = normalizedText.contains('yazilim') ||
                       normalizedText.contains('lisans') ||
                       normalizedText.contains('kurulum paketi') ||
                       normalizedText.contains('antivirus') ||
                       normalizedText.contains('vpn') ||
                       normalizedText.contains('membership') ||
                       normalizedText.contains('abonelik') ||
                       normalizedText.contains('uyelik') ||
                       normalizedText.contains('kod');
    if (isSoftware && (finalCategoryId == 'elektronik' || finalCategoryId == 'kitap_hobi')) {
      finalCategoryId = 'dijital_hizmetler';
      finalSubCategory = 'Abonelik & Yazılım';
    }

    // 9. Lego & Yetişkin Oyuncak / Maket / Puzzle Yönlendirmesi
    // Tüm LEGO'ları (Lego Duplo dahil) ve 18+/Yetişkin/Maket ibaresi barındıran oyuncakları Kitap & Hobi'ye yönlendir
    final hasLego = normalizedText.contains('lego');
    final isAdultToyOrHobby = hasLego ||
                              normalizedText.contains('18+') ||
                              normalizedText.contains('16+') ||
                              normalizedText.contains('14+') ||
                              normalizedText.contains('yetiskin') ||
                              normalizedText.contains('adult') ||
                              normalizedText.contains('maket') ||
                              normalizedText.contains('model kit') ||
                              normalizedText.contains('koleksiyon');

    if (isAdultToyOrHobby && (finalCategoryId == 'anne_bebek' || hasLego)) {
      finalCategoryId = 'kitap_hobi';
      finalSubCategory = 'Kutu Oyunları & Oyuncaklar';
    }

    // 10. Kitap Yayınevi / Banka Kampanyaları Karışıklığı
    // Eğer kategori finans_kampanyalar seçildiyse ama metin yayınevi veya kitap ibareleri barındırıyorsa kitap_hobi olmalı
    if (finalCategoryId == 'finans_kampanyalar') {
      final isBookOrPublishing = normalizedText.contains('yayinlari') ||
                                 normalizedText.contains('yayınları') ||
                                 normalizedText.contains('yayinevi') ||
                                 normalizedText.contains('yayınevi') ||
                                 normalizedText.contains('yayin') ||
                                 normalizedText.contains('yayın') ||
                                 normalizedText.contains('kitap') ||
                                 normalizedText.contains('roman') ||
                                 normalizedText.contains('dergi') ||
                                 normalizedText.contains('basim') ||
                                 normalizedText.contains('baski') ||
                                 normalizedText.contains('yazar');
      if (isBookOrPublishing) {
        finalCategoryId = 'kitap_hobi';
        finalSubCategory = 'Kitap & Dergi';
      }
    }

    // 11. Biberon / Emzirme / Bebek Beslenme Ürünleri Karışıklığı
    // Eğer 'biberon', 'emzirme', 'mama isitici' gibi kelimeler geçiyorsa her zaman 'anne_bebek' -> 'Beslenme & Emzirme' olmalı
    final isFeedingOrNursing = normalizedText.contains('biberon') ||
                               normalizedText.contains('baby bottle') ||
                               normalizedText.contains('emzirme') ||
                               normalizedText.contains('breast pump') ||
                               normalizedText.contains('gogus pompasi') ||
                               normalizedText.contains('göğüs pompası') ||
                               normalizedText.contains('mama isitici') ||
                               normalizedText.contains('mama ısıtıcı') ||
                               normalizedText.contains('biberon emzigi') ||
                               normalizedText.contains('biberon emziği') ||
                               normalizedText.contains('emzik') ||
                               normalizedText.contains('emzigi');
    if (isFeedingOrNursing) {
      finalCategoryId = 'anne_bebek';
      finalSubCategory = 'Beslenme & Emzirme';
    }

    // 12. Oyuncak (Barbie, bebek oyuncağı, vb.) / Bebek Odası Karışıklığı
    // 'oyuncak' kelimeleri + tanınmış oyuncak markaları varsa ve kategori anne_bebek ise alt kategori oyuncaklar olmalı
    if (finalCategoryId == 'anne_bebek' && finalSubCategory != 'Beslenme & Emzirme') {
      // Bebek oda/güvenlik ürünleri: telsiz, bebek arabası, bakım çantası vb. varsa dokunma
      final isBabySafetyProduct = normalizedText.contains('telsiz') ||
                                   normalizedText.contains('bebek odasi') ||
                                   normalizedText.contains('bebek odası') ||
                                   normalizedText.contains('guvenligi') ||
                                   normalizedText.contains('güvenliği') ||
                                   normalizedText.contains('oto koltuk') ||
                                   normalizedText.contains('puset') ||
                                   normalizedText.contains('bebek arabasi') ||
                                   normalizedText.contains('bebek arabası') ||
                                   normalizedText.contains('hastane canta') ||
                                   normalizedText.contains('hastane çanta') ||
                                   normalizedText.contains('bakim cantasi') ||
                                   normalizedText.contains('bakım çantası') ||
                                   normalizedText.contains('bebek bakim') ||
                                   normalizedText.contains('bebek bakım');
      final isToyProduct = !isBabySafetyProduct && (
                           normalizedText.contains('barbie') ||
                           normalizedText.contains('oyuncak bebek') ||
                           normalizedText.contains('kiz oyuncag') ||
                           normalizedText.contains('kız oyuncağ') ||
                           normalizedText.contains('oyun seti') ||
                           normalizedText.contains('hot wheels') ||
                           normalizedText.contains('matchbox') ||
                           normalizedText.contains('fisher price') ||
                           normalizedText.contains('fisher-price') ||
                           normalizedText.contains('vtech') ||
                           normalizedText.contains('playmobil'));
      if (isBabySafetyProduct) {
        if (finalSubCategory == 'Bebek & Çocuk Oyuncakları') {
          final isStrollerOrCarSeat = normalizedText.contains('puset') ||
                                       normalizedText.contains('bebek arabasi') ||
                                       normalizedText.contains('bebek arabası') ||
                                       normalizedText.contains('oto koltuk') ||
                                       normalizedText.contains('oto koltuğu') ||
                                       normalizedText.contains('bakim cantasi') ||
                                       normalizedText.contains('bakım çantası');
          if (isStrollerOrCarSeat) {
            finalSubCategory = 'Bebek Arabası & Oto Koltuğu';
          } else {
            finalSubCategory = 'Bebek Odası & Güvenlik';
          }
        }
      } else if (isToyProduct) {
        finalSubCategory = 'Bebek & Çocuk Oyuncakları';
      }
    }

    // 13. Ayakkabı / Terlik / Sandalet Yönlendirmesi (Moda altında ise her zaman Ayakkabı & Çanta olmalı)
    if (finalCategoryId == 'moda') {
      final isFootwear = normalizedText.contains('ayakkabi') ||
                          normalizedText.contains('ayakkabı') ||
                          normalizedText.contains('bot') ||
                          normalizedText.contains('cizme') ||
                          normalizedText.contains('çizme') ||
                          normalizedText.contains('terlik') ||
                          normalizedText.contains('sandalet') ||
                          normalizedText.contains('sneaker') ||
                          normalizedText.contains('babet') ||
                          normalizedText.contains('stiletto') ||
                          normalizedText.contains('topuklu') ||
                          normalizedText.contains('krampon');
      final isBabyPatik = normalizedText.contains('patik') ||
                          normalizedText.contains('bebek patik');
      if (isFootwear && !isBabyPatik) {
        finalSubCategory = 'Ayakkabı & Çanta';
      }
    }

    // 14. Yatak (Mattress/Bed) vs Ev Tekstili (Nevresim, Örtü, Yorgan)
    if (normalizedText.contains('yatak') && finalCategoryId == 'ev_yasam') {
      final isBeddingTextile = normalizedText.contains('ortu') ||
                               normalizedText.contains('örtü') ||
                               normalizedText.contains('koruyucu') ||
                               normalizedText.contains('alez') ||
                               normalizedText.contains('takim') ||
                               normalizedText.contains('takımı') ||
                               normalizedText.contains('nevresim') ||
                               normalizedText.contains('carsaf') ||
                               normalizedText.contains('çarşaf') ||
                               normalizedText.contains('kılıf') ||
                               normalizedText.contains('kilif');
      if (!isBeddingTextile) {
        finalSubCategory = 'Mobilya';
      } else {
        finalSubCategory = 'Ev Tekstili';
      }
    }

    // 15. Bebek Bakım Çantası (Bebek Arabası & Oto Koltuğu olmalı, Bebek Bezi & Islak Mendil değil)
    if (finalCategoryId == 'anne_bebek' && finalSubCategory == 'Bebek Bezi & Islak Mendil') {
      if (normalizedText.contains('canta') || normalizedText.contains('çanta')) {
        finalSubCategory = 'Bebek Arabası & Oto Koltuğu';
      }
    }

    // 16. Çamaşır/Bulaşık Makinesi Deterjanı vs Makinenin Kendisi
    final isDetergentOrSoftener = normalizedText.contains('deterjan') ||
                                   normalizedText.contains('yumusatici') ||
                                   normalizedText.contains('yumuşatıcı') ||
                                   normalizedText.contains('fairy') ||
                                   normalizedText.contains('finish') ||
                                   normalizedText.contains('calgon') ||
                                   ((normalizedText.contains('kapsul') || normalizedText.contains('kapsül')) && !normalizedText.contains('kahve') && !normalizedText.contains('cay') && !normalizedText.contains('çay') && !normalizedText.contains('espresso') && !normalizedText.contains('makine')) ||
                                   (normalizedText.contains('tablet') && (normalizedText.contains('bulasik') || normalizedText.contains('bulaşık') || normalizedText.contains('deterjan') || normalizedText.contains('makine') || normalizedText.contains('fairy') || normalizedText.contains('finish') || normalizedText.contains('calgon')));
                                    
    if (isDetergentOrSoftener) {
      final isBabyProduct = normalizedText.contains('bebek') || normalizedText.contains('baby');
      if (!isBabyProduct) {
        finalCategoryId = 'supermarket';
        finalSubCategory = 'Deterjan & Temizlik';
      }
    }

    // 17. Çay/Kahve Makinesi vs Çay/Kahve Gıda Ürünü
    if (finalCategoryId == 'supermarket' && finalSubCategory == 'Gıda Ürünleri') {
      final hasMachineWord = normalizedText.contains('makinesi') ||
                             normalizedText.contains('makineleri') ||
                             normalizedText.contains('makine') ||
                             normalizedText.contains('maker');
      if (hasMachineWord && (normalizedText.contains('kahve') || normalizedText.contains('cay') || normalizedText.contains('çay') || normalizedText.contains('nespresso') || normalizedText.contains('espresso'))) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Beyaz Eşya & Küçük Ev Aletleri';
      }
    }

    // 18. El Kremi / Vücut Kremi vs Saç Bakımı (Cilt & Yüz Bakımı olmalı)
    if (finalCategoryId == 'kozmetik' && finalSubCategory == 'Saç Bakımı') {
      final isSkinCare = normalizedText.contains('el kremi') ||
                         normalizedText.contains('el bakim') ||
                         normalizedText.contains('vucut kremi') ||
                         normalizedText.contains('vücut kremi') ||
                         normalizedText.contains('vucut losyonu') ||
                         normalizedText.contains('vücut losyonu') ||
                         normalizedText.contains('el losyonu');
      if (isSkinCare) {
        finalSubCategory = 'Cilt & Yüz Bakımı';
      }
    }

    // 19. Her Türlü Kulaklık -> Telefon & Aksesuarları
    if (finalCategoryId != 'elektronik' || finalSubCategory != 'Telefon & Aksesuarları') {
      final hasKulaklik = normalizedText.contains('kulaklik') ||
                           normalizedText.contains('kulaklık') ||
                           normalizedText.contains('headset') ||
                           normalizedText.contains('kulakligi') ||
                           normalizedText.contains('kulaklığı');
      if (hasKulaklik && !normalizedText.contains('oyuncak') && !normalizedText.contains('stand') && !normalizedText.contains('askı') && !normalizedText.contains('aski')) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Telefon & Aksesuarları';
      }
    }

    // 20. Klavye / Mouse -> Bilgisayar & Tablet
    if (finalCategoryId != 'elektronik' || finalSubCategory != 'Bilgisayar & Tablet') {
      final hasKeyboardOrMouse = normalizedText.contains('klavye') ||
                                 normalizedText.contains('klavyesi') ||
                                 normalizedText.contains('mouse') ||
                                 normalizedText.contains('oyuncu faresi') ||
                                 normalizedText.contains('kablolu fare') ||
                                 normalizedText.contains('kablosuz fare');
      if (hasKeyboardOrMouse && !normalizedText.contains('oyuncak')) {
        finalCategoryId = 'elektronik';
        finalSubCategory = 'Bilgisayar & Tablet';
      }
    }

    // 21. Bebek Islak Mendili vs Normal Islak Mendil
    if (finalCategoryId == 'supermarket' && finalSubCategory == 'Kağıt Ürünleri') {
      final hasWetWipes = normalizedText.contains('islak mendil') ||
                          normalizedText.contains('ıslak mendil') ||
                          normalizedText.contains('islak havlu') ||
                          normalizedText.contains('ıslak havlu');
      if (hasWetWipes) {
        final isBabyWipes = normalizedText.contains('bebek') ||
                            normalizedText.contains('baby') ||
                            normalizedText.contains('dalin') ||
                            normalizedText.contains('uni baby');
        if (isBabyWipes) {
          finalCategoryId = 'anne_bebek';
          finalSubCategory = 'Bebek Bezi & Islak Mendil';
        }
      }
    }

    return {
      'categoryId': finalCategoryId,
      'subCategory': finalSubCategory,
    };
  }

  /// Türkçe karakterleri normalize eder
  static String _normalizeText(String text) {
    return text
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
  }

  /// Basit Türkçe gövdeleyici (stemmer)
  static String _stem(String word) {
    if (word.length <= 3) return word;
    String w = word;
    if (w.endsWith('leri') || w.endsWith('lari')) {
      w = w.substring(0, w.length - 4);
    } else if (w.endsWith('ler') || w.endsWith('lar')) {
      w = w.substring(0, w.length - 3);
    } else if (w.endsWith('si') || w.endsWith('su')) {
      w = w.substring(0, w.length - 2);
    }
    
    if (w.endsWith('i') || w.endsWith('u')) {
      w = w.substring(0, w.length - 1);
    }
    
    if (w.endsWith('g')) {
      w = w.substring(0, w.length - 1) + 'k';
    }
    return w;
  }
}

