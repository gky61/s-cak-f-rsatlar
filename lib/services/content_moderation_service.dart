import 'package:flutter/foundation.dart' show kDebugMode;

void _log(String message) {
  if (kDebugMode) print(message);
}

/// İçerik moderasyon servisi - Küfürlü ve uygunsuz içerikleri tespit eder
class ContentModerationService {
  // Türkçe küfür ve uygunsuz kelimeler listesi
  // Bu liste sürekli güncellenebilir ve genişletilebilir
  static const List<String> _profanityWords = [
    // Genişletilmiş küfür ve uygunsuz kelimeler listesi
    'a*k', 'a*k*', 'a*k**', 'a.q', 'a.q.',
    'abaza', 'abazan', 'ag', 'ahmak', 'akilsiz',
    'akılsız', 'alkolik', 'allah', 'allahsız', 'am',
    'am biti', 'amarım', 'ambiti', 'amcik', 'amck',
    'amckl', 'amcklama', 'amcklaryla', 'amckta', 'amcktan',
    'amcuk', 'amcık', 'amcık hoşafı', 'amcıklama', 'amcıklandı',
    'amcığı', 'amcığın', 'amcığını', 'amcığınızı', 'amin oglu',
    'amina', 'amina g', 'amina k', 'amina koyarim', 'amina koyayim',
    'amina koyayım', 'aminako', 'aminakoyarim', 'aminakoyim', 'aminda',
    'amindan', 'amindayken', 'amini', 'aminiyarraaniskiim', 'aminoglu',
    'amiyum', 'amk', 'amk çocuğu', 'amkafa', 'amlarnzn',
    'amlı', 'amm', 'ammak', 'ammna', 'amn',
    'amna', 'amnda', 'amndaki', 'amngtn', 'amnn',
    'amona', 'amq', 'amsalak', 'amsiz', 'amsz',
    'amsız', 'amteri', 'amugaa', 'amuna', 'amuğa',
    'amık', 'amın feryadı', 'amın oglu', 'amın oğlu', 'amına',
    'amına koy', 'amına koyarım', 'amına koyayım', 'amına koyyim', 'amına s',
    'amına sikem', 'amına sokam', 'amınako', 'amınakoyim', 'amında',
    'amınoğlu', 'amını', 'amını s', 'amısına', 'amısını',
    'ana', 'anaaann', 'anal', 'analarn', 'anam',
    'anamla', 'anan', 'anana', 'anandan', 'anani',
    'anani sikerim', 'anani sikeyim', 'ananin', 'ananisikerim', 'ananisikeyim',
    'anann', 'ananz', 'ananı', 'ananı sikerim', 'ananı sikeyim',
    'ananın', 'ananın am', 'ananın amı', 'ananın dölü', 'ananınki',
    'ananısikerim', 'ananısikeyim', 'ananızın', 'ananızın am', 'anas',
    'anasi', 'anasinin', 'anası orospu', 'anasını', 'anasının am',
    'anay', 'anayin', 'angut', 'anneni', 'annenin',
    'annesiz', 'anuna', 'aptal', 'aq', 'aq.',
    'ass', 'atkafası', 'atmık', 'attrrm', 'attırdığım',
    'auzlu', 'avrat', 'ayklarmalrmsikerim', 'azdım', 'azdır',
    'azdırıcı', 'ağzına sıçayım', 'b*k', 'b*k*', 'babaannesi kaşar',
    'babani', 'babanı', 'babanın', 'babası pezevenk', 'bacağına sıçayım',
    'bacini', 'bacn', 'bacndan', 'bacy', 'bacına',
    'bacını', 'bacının', 'bastard', 'basur', 'bedava para',
    'beyinsiz', 'bitch', 'biting', 'bok', 'boka',
    'bokbok', 'bokhu', 'bokkkumu', 'boklar', 'boktan',
    'boku', 'bokubokuna', 'bokum', 'bokça', 'bomba',
    'bombala', 'bombalamak', 'bombok', 'boner', 'bosalmak',
    'boşalmak', 'bızır', 'cenabet', 'cibiliyetsiz', 'cibilliyetini',
    'cibilliyetsiz', 'cif', 'cikar', 'cim', 'cuk',
    'cukmek', 'd*k', 'd*k*', 'dalaksız', 'dallama',
    'daltassak', 'dalyarak', 'dalyarrak', 'dangalak', 'dassagi',
    'daşak', 'daşağı', 'daşşak', 'daşşağı', 'dik',
    'dikmek', 'diktim', 'dildo', 'dingil', 'dingilini',
    'dinsiz', 'dkerim', 'dolandir', 'dolandır', 'domal',
    'domalan', 'domaldı', 'domaldın', 'domalmak', 'domalmış',
    'domalsın', 'domalt', 'domaltarak', 'domaltip', 'domaltmak',
    'domaltıp', 'domaltır', 'domaltırım', 'domalık', 'domalıyor',
    'domuz', 'domuzluk', 'döl', 'dölü', 'dönek',
    'düdük', 'eben', 'ebeni', 'ebenin', 'ebeninki',
    'ebleh', 'ecdadini', 'ecdadını', 'embesil', 'emi',
    'eroin', 'esrar', 'fahise', 'fahişe', 'feriştah',
    'ferre', 'folloş', 'fuck', 'fucker', 'fuckin',
    'fucking', 'g*t', 'g*t*', 'gavad', 'gavat',
    'geber', 'geberik', 'gebermek', 'gebermiş', 'gebertir',
    'geri zekalı', 'gerizekali', 'gerizekalı', 'gerzek', 'gerızekalı',
    'giberim', 'giberler', 'gibis', 'gibiş', 'gibmek',
    'gibtiler', 'goddamn', 'godoş', 'godumun', 'got',
    'gotelek', 'gotlalesi', 'gotlu', 'gotten', 'gotu',
    'gotundeki', 'gotunden', 'gotune', 'gotunu', 'gotveren',
    'goyiim', 'goyum', 'goyuyim', 'goyyim', 'gtelek',
    'gtn', 'gtnde', 'gtnden', 'gtne', 'gtten',
    'gtveren', 'göt', 'göt deliği', 'göt herif', 'göt oğlanı',
    'göt veren', 'göt verir', 'götelek', 'götlalesi', 'götlek',
    'götoğlanı', 'götoş', 'götten', 'götveren', 'götü',
    'götün', 'götüne', 'götüne koyim', 'götünekoyim', 'götünü',
    'has siktir', 'hasiktir', 'hassikome', 'hassiktir', 'hassittir',
    'haysiyetsiz', 'hayvan herif', 'hizli para', 'hoşafı', 'hsktr',
    'huur', 'hödük', 'ibina', 'ibine', 'ibinenin',
    'ibne', 'ibnedir', 'ibneleri', 'ibnelik', 'ibnelri',
    'ibneni', 'ibnenin', 'ibnerator', 'ibnesi', 'idiot',
    'idiyot', 'imansz', 'ipne', 'iserim', 'it',
    'it oglu it', 'it oğlu it', 'itoğlu it', 'işerim', 'k*',
    'k**', 'k***', 'kafam girsin', 'kafasiz', 'kafasız',
    'kahbe', 'kahpe', 'kahpenin', 'kahpenin feryadı', 'kaka',
    'kaltak', 'kaltağ', 'kancik', 'kancık', 'kancığ',
    'kappe', 'karhane', 'katlet', 'katletmek', 'kavat',
    'kavatn', 'kaypak', 'kayyum', 'kazan', 'kazanmak',
    'kaşar', 'kerane', 'kerhane', 'kerhaneci', 'kerhanelerde',
    'kevase', 'kevaşe', 'kevvase', 'koca göt', 'kodumun',
    'kodumunun', 'koduumun', 'koduğmun', 'koduğmunun', 'kokain',
    'kopek', 'koyarm', 'koyayım', 'koyiim', 'koyiiym',
    'koyim', 'koyum', 'koyyim', 'krar', 'kukudaym',
    'köpek', 'laciye boyadım', 'lavuk', 'liboş', 'm*k',
    'm*k*', 'madafaka', 'mal', 'malafat', 'malak',
    'malk', 'manyak', 'masturbasyon', 'masturbate', 'mastürbasyon',
    'mastırbasyon', 'mcik', 'meme', 'memelerini', 'mezveleli',
    'minaamcık', 'mincikliyim', 'mna', 'monakkoluyum', 'motherfucker',
    'mudik', 'namussuz', 'namusuz', 'o*', 'o**',
    'o***', 'o. çocuğu', 'o.ç', 'o.ç.', 'oc',
    'ocuu', 'ocuun', 'oldur', 'oldurmek', 'oral',
    'orgasm', 'orgazm', 'orosbu', 'orosbucocuu', 'orospu',
    'orospu cocugu', 'orospu çoc', 'orospu çocukları', 'orospu çocuğu', 'orospu çocuğudur',
    'orospucocugu', 'orospudur', 'orospular', 'orospunun', 'orospunun evladı',
    'orospuydu', 'orospuyuz', 'orospuçocuğu', 'orostoban', 'orostopol',
    'orrospu', 'orsp', 'orusbu', 'oruspu', 'oruspu çocuğu',
    'oruspuçocuğu', 'osbir', 'ossurduum', 'ossurmak', 'ossuruk',
    'osur', 'osurduu', 'osuruk', 'osururum', 'otuzbir',
    'oç', 'oğlan', 'oğlancı', 'oğlu it', 'p*',
    'p**', 'p***', 'para kazan', 'patlak zar', 'penis',
    'pezevek', 'pezeven', 'pezeveng', 'pezevengi', 'pezevengin evladı',
    'pezevenk', 'pezo', 'pic', 'pici', 'picler',
    'piclik', 'pipi', 'pipiş', 'pisliktir', 'piç',
    'piç kurusu', 'piçin oğlu', 'piçler', 'piçlik', 'porno',
    'pornografi', 'pussy', 'puşt', 'puşttur', 'pzvnk',
    'qavat', 'rahminde', 'revizyonist', 's*k', 's*k*',
    's*k**', 's*k***', 's1kerim', 's1kerm', 's1krm',
    'sakso', 'saksofon', 'salaak', 'salak', 'sarhos',
    'sarhoş', 'saxo', 'sekis', 'seks', 'serefsiz',
    'sevgi koyarım', 'sevişelim', 'sex', 'sexs', 'sicarsin',
    'sie', 'sik', 'sikdi', 'sikdiğim', 'sike',
    'sikecem', 'sikem', 'siken', 'sikenin', 'siker',
    'sikerim', 'sikerler', 'sikersin', 'sikertir', 'sikertmek',
    'sikesen', 'sikesicenin', 'sikey', 'sikeydim', 'sikeyim',
    'sikeym', 'siki', 'sikicem', 'sikici', 'sikien',
    'sikienler', 'sikiiim', 'sikiiimmm', 'sikiim', 'sikiir',
    'sikiirken', 'sikik', 'sikil', 'sikildiini', 'sikilesice',
    'sikilmi', 'sikilmie', 'sikilmis', 'sikilmiş', 'sikilsin',
    'sikim', 'sikimde', 'sikimden', 'sikime', 'sikimi',
    'sikimiin', 'sikimin', 'sikimle', 'sikimsonik', 'sikimtrak',
    'sikin', 'sikinde', 'sikinden', 'sikine', 'sikini',
    'sikip', 'sikis', 'sikisek', 'sikisen', 'sikish',
    'sikismis', 'sikitiin', 'sikiyim', 'sikiym', 'sikiyorum',
    'sikiş', 'sikişen', 'sikişme', 'sikkim', 'sikko',
    'sikle', 'sikleri', 'sikleriii', 'sikli', 'sikm',
    'sikme', 'sikmek', 'sikmem', 'sikmiler', 'sikmisligim',
    'siksem', 'sikseydin', 'sikseyidin', 'siksin', 'siksinbaya',
    'siksinler', 'siksiz', 'siksok', 'siksz', 'sikt',
    'sikti', 'siktigimin', 'siktigiminin', 'siktii', 'siktiim',
    'siktiimin', 'siktiiminin', 'siktiler', 'siktim', 'siktimin',
    'siktiminin', 'siktir', 'siktir et', 'siktir git', 'siktir lan',
    'siktir ol git', 'siktirgit', 'siktirir', 'siktiririm', 'siktiriyor',
    'siktirolgit', 'siktiği', 'siktiğim', 'siktiğimin', 'siktiğiminin',
    'silah', 'silahla', 'silahlamak', 'sittimin', 'sittir',
    'skcem', 'skecem', 'skem', 'sker', 'skerim',
    'skerm', 'skeyim', 'skiim', 'skik', 'skim',
    'skime', 'skmek', 'sksin', 'sksn', 'sksz',
    'sktiimin', 'sktr', 'sktrr', 'skyim', 'slaleni',
    'sokam', 'sokarim', 'sokarm', 'sokarmkoduumun', 'sokarım',
    'sokaym', 'sokayım', 'sokiim', 'soktuğumunun', 'sokuk',
    'sokum', 'sokuyum', 'sokuş', 'soxum', 'sperm',
    'sulaleni', 'sülaleni', 'sülalenizi', 'sürtük', 'sıecem',
    'sıçar', 'sıçarım', 'sıçayım', 'sıçmak', 'sıçsın',
    'sıçtığım', 't*k', 't*k*', 'taaklarn', 'taaklarna',
    'tarrakimin', 'tasak', 'tassak', 'taşak', 'taşağa',
    'taşağı', 'taşşak', 'taşşağa', 'taşşağı', 'tik',
    'tikmek', 'tipini s.k', 'tipinizi s.keyim', 'tiyniyat', 'toplarm',
    'topsun', 'totoş', 'uyusturucu', 'uyuşturucu', 'vajina',
    'vajinanı', 'veled', 'veled i zina', 'veledizina', 'verdiimin',
    'weled', 'weledizina', 'whore', 'xikeyim', 'y*k',
    'y*k*', 'yaaraaa', 'yalaka', 'yalama', 'yalarun',
    'yalarım', 'yaraaam', 'yarak', 'yaraksız', 'yaraktr',
    'yaram', 'yaraminbasi', 'yaramn', 'yararmorospunun', 'yarağ',
    'yarra', 'yarraaaa', 'yarraak', 'yarraam', 'yarraamı',
    'yarragi', 'yarragimi', 'yarragina', 'yarragindan', 'yarragm',
    'yarraimin', 'yarrak', 'yarram', 'yarramin', 'yarraminbaşı',
    'yarramn', 'yarran', 'yarrana', 'yarrağ', 'yarrağım',
    'yarrağımı', 'yarrrak', 'yavak', 'yavuşak', 'yavş',
    'yavşak', 'yavşaktır', 'yik', 'yikmek', 'yilisik',
    'yogurtlayam', 'yoğurtlayam', 'yrrak', 'yrrk', 'yılışık',
    'z*k', 'z*k*', 'zibidi', 'zigsin', 'zik',
    'zikeyim', 'zikiiim', 'zikiim', 'zikik', 'zikim',
    'zikmek', 'ziksiiin', 'ziksiin', 'zulliyetini', 'zviyetini',
    'zıkkımım', 'ç*k', 'ç*k*', 'çük', 'çükmek',
    'öküz', 'öldür', 'öldürmek', 'öşex', 'ıbnelık',
    'şerefsiz', 'şıllık',
  ];

  // Normalize fonksiyonu - Türkçe karakterleri İngilizce karşılıklarına çevirir
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ş', 's')
        .replaceAll('ü', 'u')
        .replaceAll('İ', 'i')
        .replaceAll('Ç', 'c')
        .replaceAll('Ğ', 'g')
        .replaceAll('Ö', 'o')
        .replaceAll('Ş', 's')
        .replaceAll('Ü', 'u');
  }

  // Kelimeleri ayır ve normalize et
  static List<String> _tokenize(String text) {
    final normalized = _normalize(text);
    // Noktalama işaretlerini kaldır ve kelimelere ayır
    final cleaned = normalized.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  }

  // Küfür kontrolü yap
  static bool containsProfanity(String text) {
    if (text.isEmpty) return false;
    
    final words = _tokenize(text);
    final normalizedText = _normalize(text);
    
    // Her küfür kelimesini kontrol et
    for (final profanity in _profanityWords) {
      final normalizedProfanity = _normalize(profanity);
      
      // Tam kelime eşleşmesi kontrolü (yanlış pozitifleri önlemek için sadece tam kelimelere bakarız)
      final regex = RegExp(r'\b' + RegExp.escape(normalizedProfanity) + r'\b');
      if (regex.hasMatch(normalizedText)) {
        _log('⚠️ Küfür tespit edildi: "$profanity" içerikte: "${text.substring(0, text.length > 50 ? 50 : text.length)}..."');
        return true;
      }
    }
    
    return false;
  }

  // İçerik moderasyonu - Başlık ve açıklama kontrolü
  static ModerationResult moderateContent({
    required String? title,
    required String? description,
  }) {
    if (title == null && description == null) {
      return ModerationResult(isSafe: true);
    }

    final titleText = title ?? '';
    final descriptionText = description ?? '';
    final combinedText = '$titleText $descriptionText';

    if (containsProfanity(combinedText)) {
      return ModerationResult(
        isSafe: false,
        reason: 'İçerik uygunsuz kelimeler içeriyor. Lütfen daha uygun bir dil kullanın.',
      );
    }

    return ModerationResult(isSafe: true);
  }

  // Yorum moderasyonu
  static ModerationResult moderateComment(String commentText) {
    if (commentText.isEmpty) {
      return ModerationResult(isSafe: true);
    }

    if (containsProfanity(commentText)) {
      return ModerationResult(
        isSafe: false,
        reason: 'Yorumunuz uygunsuz kelimeler içeriyor. Lütfen daha uygun bir dil kullanın.',
      );
    }

    return ModerationResult(isSafe: true);
  }
}

/// Moderasyon sonucu
class ModerationResult {
  final bool isSafe;
  final String? reason;

  ModerationResult({
    required this.isSafe,
    this.reason,
  });
}





