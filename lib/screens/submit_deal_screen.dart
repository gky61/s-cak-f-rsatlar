import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/category_detection_service.dart';
import '../models/category.dart';
import '../widgets/category_selector_widget.dart';

class SubmitDealScreen extends StatefulWidget {
  const SubmitDealScreen({super.key});

  @override
  State<SubmitDealScreen> createState() => _SubmitDealScreenState();
}

class _SubmitDealScreenState extends State<SubmitDealScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _storeController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _urlController = TextEditingController();
  
  String _selectedCategory = 'elektronik';
  String? _selectedSubCategory;
  bool _isLoading = false;
  bool _isAutoDetecting = false;

  @override
  void initState() {
    super.initState();
    // Başlık veya açıklama değiştiğinde kategori tespit et
    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty && description.isEmpty) return;
    
    // Kısa bir gecikme ile tespit yap (kullanıcı yazmayı bitirsin)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _isAutoDetecting) return;
      _detectCategory();
    });
  }

  void _detectCategory() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty && description.isEmpty) return;
    
    // Başlık ve açıklamayı birleştir
    final combinedText = '$title $description';
    
    print('🔍 Kategori tespiti yapılıyor: $combinedText');
    final result = CategoryDetectionService.detectCategory(combinedText);
    print('✅ Tespit sonucu: $result');
    
    if (result != null && mounted) {
      final categoryId = result['categoryId'];
      final subCategory = result['subCategory'];
      
      if (categoryId != null && categoryId != _selectedCategory) {
        print('📝 Kategori güncelleniyor: $categoryId, alt kategori: $subCategory');
        _isAutoDetecting = true;
        setState(() {
          _selectedCategory = categoryId;
          _selectedSubCategory = subCategory;
        });
        _isAutoDetecting = false;
        
        print('✅ Kategori güncellendi: ${Category.getById(categoryId).name}');
        
        // Kullanıcıya bildirim göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kategori otomatik tespit edildi: ${Category.getById(categoryId).name}${subCategory != null ? " > $subCategory" : ""}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Değiştir',
                textColor: Colors.white,
                onPressed: () => _showCategorySelector(),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _storeController.dispose();
    _imageUrlController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _getCategoryDisplayText() {
    final category = Category.getById(_selectedCategory);
    if (_selectedSubCategory != null) {
      return '${category.icon} ${category.name} > $_selectedSubCategory';
    }
    return '${category.icon} ${category.name}';
  }

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategorySelectorWidget(
        selectedCategoryId: _selectedCategory,
        selectedSubCategory: _selectedSubCategory,
        onCategorySelected: (categoryId, subCategory) {
          setState(() {
            _isAutoDetecting = false; // Manuel seçim yapıldı, otomatik tespiti durdur
            _selectedCategory = categoryId;
            _selectedSubCategory = subCategory;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _submitDeal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat paylaşmak için giriş yapmalısınız'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.createDeal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        store: _storeController.text.trim(),
        category: Category.getNameById(_selectedCategory),
        subCategory: _selectedSubCategory,
        imageUrl: _imageUrlController.text.trim(),
        url: _urlController.text.trim(),
        userId: user.uid,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fırsat başarıyla paylaşıldı!'),
            backgroundColor: Color(0xFFFF6B35),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fırsat Paylaş',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Başlık
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Başlık *',
                hintText: 'Örn: iPhone 15 Pro Max',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Başlık gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kategori Seçimi
            InkWell(
              onTap: () => _showCategorySelector(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                        child: Row(
                          children: [
                    const Icon(Icons.category, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kategori *',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                        ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCategoryDisplayText(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Fiyat
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Fiyat (₺) *',
                hintText: 'Örn: 999.99',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Fiyat gerekli';
                }
                if (double.tryParse(value) == null) {
                  return 'Geçerli bir fiyat girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Mağaza
            TextFormField(
              controller: _storeController,
              decoration: InputDecoration(
                labelText: 'Mağaza *',
                hintText: 'Örn: Trendyol, Hepsiburada',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.store),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Mağaza gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Açıklama *',
                hintText: 'Fırsat hakkında detaylar',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Açıklama gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Ürün URL
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Ürün Linki *',
                hintText: 'https://...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ürün linki gerekli';
                }
                if (!value.startsWith('http')) {
                  return 'Geçerli bir URL girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Resim URL
            TextFormField(
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: 'Resim Linki',
                hintText: 'https://...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.image),
              ),
            ),
            const SizedBox(height: 24),

            // Gönder butonu
            ElevatedButton(
              onPressed: _isLoading ? null : _submitDeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Fırsatı Paylaş',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
