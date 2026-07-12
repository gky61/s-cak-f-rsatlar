import 'package:sicak_firsatlar/services/category_detection_service.dart';

void main() {
  print('Keywords for Bebek & Çocuk Oyuncakları:');
  // CategoryDetectionService._categoryKeywords is private, but detectCategory is public.
  // We can call detectCategory with "lego" and see where it maps!
  final res = CategoryDetectionService.detectCategory('lego');
  print('Result for lego: $res');
}
