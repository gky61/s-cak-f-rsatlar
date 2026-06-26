# Firestore Composite Index Gereksinimleri

## Yorumlar için Composite Index

Web admin panelinde kullanıcı yorumlarını görüntülemek için aşağıdaki composite index gereklidir:

### Index Detayları:
- **Collection Group**: `comments`
- **Fields**:
  1. `userId` (Ascending)
  2. `createdAt` (Descending)

### Index Oluşturma:

1. **Otomatik (Önerilen):**
   - Web admin panelinde bir kullanıcının yorumlarını görüntülemeyi deneyin
   - Firebase Console'da bir hata mesajı görünecek
   - Hata mesajındaki linke tıklayarak index'i otomatik oluşturabilirsiniz

2. **Manuel:**
   - Firebase Console'a gidin: https://console.firebase.google.com
   - Projenizi seçin
   - Firestore Database > Indexes sekmesine gidin
   - "Create Index" butonuna tıklayın
   - Collection ID: `comments` (Collection Group olarak işaretleyin)
   - Fields ekleyin:
     - `userId` - Ascending
     - `createdAt` - Descending
   - "Create" butonuna tıklayın

### Index Oluşturulmazsa:
- Sistem otomatik olarak fallback yöntemine geçer
- Fallback yöntemi daha yavaş çalışır (tüm deal'leri kontrol eder)
- Performans için index oluşturulması önerilir

### Performans Notları:
- Index ile: ~100ms (1000 yorum için)
- Index olmadan: ~5-10 saniye (100 deal, her deal'de 50 yorum)
- Index oluşturulması 1-2 dakika sürebilir





