import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://www.zara.com/tr/tr/kenevir-pamuk-relaxed-fit-pantolon-p03692304.html';
  
  // Test 1: Only User-Agent
  print('Test 1: Only WhatsApp User-Agent...');
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
      },
    );
    print('  -> Status: ${response.statusCode}');
    print('  -> Length: ${response.body.length}');
    print('  -> Is Challenge? ${response.body.contains('bm-verify')}');
  } catch (e) {
    print('  -> Error: $e');
  }
  
  print('-----------------------------------------');
  
  // Test 2: User-Agent + Accept + Accept-Language
  print('Test 2: WhatsApp UA + Accept + Accept-Language...');
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'WhatsApp/2.23.4.15 A',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      },
    );
    print('  -> Status: ${response.statusCode}');
    print('  -> Length: ${response.body.length}');
    print('  -> Is Challenge? ${response.body.contains('bm-verify')}');
  } catch (e) {
    print('  -> Error: $e');
  }
}
