import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.zara.com/tr/tr/kenevir-pamuk-relaxed-fit-pantolon-p03692304.html';
  
  final userAgents = {
    'WhatsApp': 'WhatsApp/2.23.4.15 A',
    'Googlebot (Desktop)': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Googlebot (Mobile)': 'Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Bingbot': 'Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)',
    'Facebookbot': 'facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_voiced_listening.html)',
    'Twitterbot': 'Twitterbot/1.0',
    'Standard Chrome': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
  };
  
  for (final entry in userAgents.entries) {
    print('Testing UA: ${entry.key}...');
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': entry.value,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      ).timeout(Duration(seconds: 8));
      
      print('  -> Status: ${response.statusCode}');
      print('  -> Length: ${response.body.length}');
      final isChallenge = response.body.contains('bm-verify');
      print('  -> Is Akamai Challenge? $isChallenge');
      print('  -> Contains analyticsData? ${response.body.contains('zara.analyticsData')}');
    } catch (e) {
      print('  -> Error: $e');
    }
    print('-----------------------------------------');
  }
}
