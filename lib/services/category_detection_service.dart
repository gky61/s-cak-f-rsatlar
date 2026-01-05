import 'package:flutter/foundation.dart' show kDebugMode;
import '../models/category.dart';

void _log(String message) {
  if (kDebugMode) _log(message);
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
        'ram', 'memory', 'bellek', 'graphics card', 'ekran kartı', 'ekran karti', 'gpu', 'cpu', 'işlemci', 'islemci'
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
        'aspiratör', 'hood', 'mutfak aspiratörü', 'mutfak aspiratoru', 'davlumbaz',
        'elektrikli süpürge', 'elektrikli supurge', 'vacuum cleaner', 'dikey süpürge', 'dikey supurge',
        'robot süpürge', 'robot supurge', 'robot vacuum', 'roomba', 'dyson', 'xiaomi robot',
        'ütü', 'utu', 'iron', 'buharlı ütü', 'buharli utu', 'steam iron',
        'kahve makinesi', 'coffee maker', 'espresso', 'filtre kahve', 'turk kahvesi', 'turk kahvesi',
        'su ısıtıcı', 'su isiticisi', 'kettle', 'electric kettle', 'çaydanlık', 'caydanlik',
        'tost makinesi', 'toaster', 'sandwich maker', 'tost', 'waffle maker', 'waffle makinesi',
        'mikser', 'mixer', 'hand mixer', 'el mikseri', 'stand mixer', 'ayaklı mikser', 'ayakli mikser',
        'blender', 'smoothie maker', 'mutfak robotu', 'food processor', 'rondo',
        'mini buzdolabı', 'mini buzdolabi', 'mini fridge', 'camping fridge'
      ],
      'Fotoğraf & Kamera': [
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
      'Saat & Aksesuar': [
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
        'brooch', 'rozet', 'tie', 'kravat', 'cufflinks', 'kol düğmesi', 'kol dugmesi'
      ],
      'Çocuk Giyim': [
        'çocuk', 'cocuk', 'bebek', 'çocuk giyim', 'cocuk giyim', 'bebek giyim', "children's", "kids'", "baby",
        'çocuk elbise', 'cocuk elbise', 'bebek elbise', 'çocuk pantolon', 'cocuk pantolon', 'bebek pantolon',
        'çocuk tişört', 'cocuk tisort', 'bebek tişört', 'çocuk kazak', 'cocuk kazak', 'bebek kazak',
        'çocuk mont', 'cocuk mont', 'bebek mont', 'çocuk ceket', 'cocuk ceket', 'bebek ceket',
        'çocuk ayakkabı', 'cocuk ayakkabi', "children's shoes", "kids' shoes", 'bebek ayakkabı', 'bebek ayakkabi',
        'okul kıyafeti', 'okul kiyafeti', 'school uniform', 'okul forması', 'okul formasi',
        'çocuk çanta', 'cocuk canta', "kids' bag", 'bebek çanta', 'bebek canta', 'okul çantası', 'okul cantasi',
        'bebek bezi', 'diaper', 'çocuk iç çamaşırı', 'cocuk ic camasiri', "children's underwear",
        'çocuk oyuncak', 'cocuk oyuncak', "kids' toy", 'bebek oyuncak', 'baby toy'
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
        'makas', 'scissors', 'yapıştırıcı', 'yapisirici', 'glue', 'bant', 'tape', 'scotch tape',
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
        'sling', 'baby sling', 'ergonomic carrier', 'bebek askısı', 'bebek askisi'
      ],
      'Beslenme & Emzirme': [
        'biberon', 'bottle', 'baby bottle', 'emzik', 'pacifier', 'dummy',
        'mama kabı', 'mama kabi', 'feeding bowl', 'mama kaşığı', 'mama kasigi', 'feeding spoon',
        'suluk', 'sippy cup', 'bebek çatalı', 'bebek catali', 'baby fork',
        'emzirme yastığı', 'emzirme yastigi', 'nursing pillow', 'göğüs pompası', 'gogus pompasi',
        'breast pump', 'süt saklama', 'sut saklama', 'breast milk storage', 'mama ısıtıcı', 'mama isiticisi',
        'bottle warmer', 'sterilizatör', 'sterilizer', 'biberon sterilizatörü'
      ],
      'Bebek Odası & Güvenlik': [
        'bebek yatağı', 'bebek yatagi', 'baby bed', 'beşik', 'besik', 'crib', 'bebek karyolası',
        'bebek karyolasi', 'baby crib', 'bebek odası', 'bebek odasi', 'nursery', 'bebek mobilya',
        'bebek mobilya', 'baby furniture', 'bebek güvenlik', 'bebek guvenlik', 'baby safety',
        'bebek kapısı', 'bebek kapisi', 'baby gate', 'priz koruyucu', 'outlet cover',
        'köşe koruyucu', 'kose koruyucu', 'corner guard', 'bebek monitörü', 'baby monitor'
      ],
      'Bebek Oyuncakları': [
        'bebek oyuncak', 'bebek oyuncak', 'baby toy', 'oyuncak', 'toy', 'eğitici oyuncak',
        'egitici oyuncak', 'educational toy', 'bebek oyuncağı', 'bebek oyuncagi',
        'peluş oyuncak', 'pelus oyuncak', 'plush toy', 'stuffed animal', 'bebek bebek', 'doll',
        'oyuncak araba', 'toy car', 'lego', 'duplo', 'puzzle', 'yapboz', 'building blocks',
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
        'yaslanma karsiti', 'retinol', 'vitamin c', 'c vitamini', 'hyaluronic acid', 'hyaluronik asit'
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
        'eşofman', 'esofman', 'tracksuit', 'şort', 'sort', 'shorts', 'tişört', 'tisort', 't-shirt',
        'spor çorap', 'spor corap', 'sports socks', 'spor çanta', 'spor canta', 'gym bag', 'mat',
        'yoga matı', 'yoga mati', 'yoga mat', 'pilates matı', 'pilates mati', 'pilates mat',
        'dambıl', 'dumbbell', 'halter', 'barbell', 'ağırlık', 'agirlik', 'weight', 'kettlebell'
      ],
      'Fitness & Kondisyon': [
        'fitness', 'koşu bandı', 'kosu bandi', 'treadmill', 'bisiklet', 'bike', 'exercise bike',
        'eliptik', 'elliptical', 'dambıl', 'dumbbell', 'halter', 'barbell', 'ağırlık seti',
        'agirlik seti', 'weight set', 'fitness ekipman', 'fitness equipment', 'ev spor aleti',
        'ev spor aleti', 'home gym', 'bench', 'bench press', 'smith machine', 'cable machine',
        'pull up bar', 'barfiks', 'resistance band', 'direnç bandı', 'direnc bandi'
      ],
      'Kamp & Doğa Malzemeleri': [
        'çadır', 'cadir', 'tent', 'uyku tulumu', 'uyku tulumu', 'sleeping bag', 'mat', 'sleeping mat',
        'kamp', 'camping', 'kamp malzemesi', 'kamp malzemesi', 'camping gear', 'kamp çantası',
        'kamp cantasi', 'backpack', 'kamp sandalyesi', 'camping chair', 'kamp masası', 'camping table',
        'fener', 'flashlight', 'torch', 'kafa lambası', 'kafa lambasi', 'headlamp', 'termos',
        'thermos', 'kamp ocağı', 'kamp ocagi', 'camping stove', 'tüp', 'tup', 'gas canister',
        'doğa yürüyüşü', 'doga yuruyusu', 'hiking', 'trekking', 'trekking pole', 'yürüyüş batonu'
      ],
      'Bisiklet & Ekipmanları': [
        'bisiklet', 'bicycle', 'bike', 'mountain bike', 'mtb', 'şehir bisikleti', 'sehir bisikleti',
        'city bike', 'elektrikli bisiklet', 'elektrikli bisiklet', 'e-bike', 'electric bike',
        'bisiklet kaskı', 'bisiklet kaski', 'bike helmet', 'bisiklet aksesuar', 'bike accessory',
        'bisiklet pompası', 'bisiklet pompasi', 'bike pump', 'bisiklet kilidi', 'bike lock',
        'bisiklet gözlüğü', 'bike glasses', 'bisiklet eldiveni', 'bike gloves', 'bisiklet çantası', 'bike bag'
      ],
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
      'Elektrikli Aletler & Hırdavat': [
        'matkap', 'drill', 'vidalama', 'screwdriver', 'tornavida', 'screwdriver', 'anahtar', 'wrench',
        'pense', 'pliers', 'çekiç', 'cekic', 'hammer', 'keski', 'chisel', 'testere', 'saw',
        'elektrikli alet', 'power tool', 'akülü matkap', 'akulu matkap', 'cordless drill',
        'şarjlı matkap', 'sarjli matkap', 'hırdavat', 'hirdavat', 'hardware', 'vida', 'screw',
        'çivi', 'civi', 'nail', 'dübel', 'dubel', 'dowel', 'zımba', 'zimba', 'stapler', 'zımba teli',
        'zimba teli', 'staple', 'angle grinder', 'açılı taşlama', 'acili taslama', 'circular saw', 'daire testere'
      ],
      'Oto Aksesuar & Bakım': [
        'oto', 'araba', 'car', 'araç', 'vehicle', 'oto aksesuar', 'car accessory', 'araç aksesuar',
        'koltuk kılıfı', 'koltuk kilifi', 'seat cover', 'paspas', 'floor mat', 'araç paspası',
        'arac paspasi', 'car mat', 'araç temizlik', 'arac temizlik', 'car cleaning', 'cam suyu',
        'windshield washer fluid', 'motor yağı', 'motor yagi', 'engine oil', 'fren balata',
        'brake pad', 'lastik', 'tire', 'jant', 'rim', 'wheel', 'araç bakım', 'arac bakim', 'car maintenance',
        'oto bakım', 'car service', 'araç kokusu', 'car air freshener', 'araç şarj', 'car charger'
      ],
      'Banyo & Tesisat': [
        'banyo', 'bathroom', 'lavabo', 'sink', 'klozet', 'toilet', 'duşakabin', 'dusakabin', 'shower cabin',
        'küvet', 'kuvet', 'bathtub', 'musluk', 'faucet', 'batarya', 'tap', 'duş başlığı', 'dus basligi',
        'shower head', 'banyo aksesuar', 'bathroom accessory', 'banyo dolabı', 'bathroom cabinet',
        'ayna', 'mirror', 'banyo aynası', 'bathroom mirror', 'havlu askısı', 'towel rack',
        'sabunluk', 'soap dispenser', 'diş fırçası kabı', 'dis fircasi kabi', 'toothbrush holder',
        'duş perdesi', 'dus perdesi', 'shower curtain', 'banyo paspası', 'bath mat'
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
        'microphone', 'hoparlör', 'speaker', 'amplifier', 'amp', 'amplifikatör', 'amplifikator'
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
        'yagli boya', 'oil paint', 'guaj', 'gouache', 'maket', 'model', 'model kit', 'puzzle',
        'yapboz', 'jigsaw puzzle', 'lego', 'oyuncak', 'toy', 'el işi', 'el isi', 'handicraft',
        'dikiş', 'dikis', 'sewing', 'nakış', 'nakis', 'embroidery', 'örgü', 'orgu', 'knitting',
        'tığ', 'tig', 'crochet hook', 'şiş', 'sis', 'knitting needle', 'iplik', 'yarn', 'thread',
        'kumaş', 'fabric', 'cloth', 'scissors', 'makas', 'ruler', 'cetvel'
      ],
    },
  };

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
          
          // Metni kelimelere ayır
          final words = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));
          final originalWords = originalText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+'));
          
          // Tam kelime eşleşmesi (en yüksek skor - öncelikli)
          bool exactWordMatch = false;
          for (int i = 0; i < words.length; i++) {
            final word = words[i];
            final originalWord = originalWords.length > i ? originalWords[i] : '';
            
            // Tam kelime eşleşmesi
            if (word == normalizedKeyword || originalWord == originalKeyword) {
              score += 5.0; // Tek kelime için yüksek skor
              exactWordMatch = true;
              _log('   ✅ Tam kelime eşleşmesi: "$keyword" (+5.0)');
              break;
            }
          }
          
          // Tam eşleşme (keyword metin içinde geçiyor) - eğer tam kelime eşleşmesi yoksa
          if (!exactWordMatch) {
            if (normalizedText.contains(normalizedKeyword) || originalText.contains(originalKeyword)) {
              score += 3.0;
              _log('   ✅ Tam eşleşme: "$keyword" (+3.0)');
            }
          }
          
          // Kelime bazlı eşleşme (orta skor) - sadece tam eşleşme yoksa
          if (!exactWordMatch) {
            for (final word in words) {
              if (word.length >= 3) {
                // Kelime keyword içinde geçiyor mu?
                if (normalizedKeyword.contains(word)) {
                  score += 1.0;
                }
                // Keyword kelime içinde geçiyor mu?
                if (word.contains(normalizedKeyword)) {
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

    // Minimum skor eşiği (çok düşük skorları kabul etme)
    // Tek kelimeli aramalar için daha düşük eşik (örn: "saat", "tablet")
    final minScore = normalizedText.split(RegExp(r'[^\wğüşıöçĞÜŞİÖÇ]+')).length == 1 ? 1.0 : 1.5;
    if (bestScore < minScore) {
      _log('❌ Skor çok düşük: $bestScore (minimum: $minScore)');
      return null;
    }

    _log('✅ En iyi eşleşme: $bestCategoryId > $bestSubCategory (skor: $bestScore)');

    return {
      'categoryId': bestCategoryId,
      'subCategory': bestSubCategory,
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
}

