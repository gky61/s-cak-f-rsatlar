import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.zara.com/tr/tr/kenevir-pamuk-relaxed-fit-pantolon-p03692304.html';
  
  final userAgents = {
    'Apple TV': 'Mozilla/5.0 (AppleTV; OS X 10.11.4) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13Y234 Safari/601.1.46',
    'LG Smart TV': 'Mozilla/5.0 (Web0S; Linux/SmartTV) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36 LG Browser/8.00.00(LGEB9N)',
    'Roku': 'Roku/DVP-9.10 (519.10E04111A)',
    'PlayStation 5': 'Mozilla/5.0 (PlayStation; PlayStation 5/2.26) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/13.0 Safari/605.1.15',
    'Googlebot News': 'Mozilla/5.0 (compatible; Googlebot-News; +http://www.google.com/bot.html)',
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
