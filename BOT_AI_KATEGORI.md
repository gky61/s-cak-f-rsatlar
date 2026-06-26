# Telegram Bot – AI ile Kategori Tespiti

Bot artık **Gemini AI** ile çekilen fırsatların kategorisini otomatik tespit ediyor. API key tanımlı değilse sadece anahtar kelime eşlemesi kullanılır.

## Gemini API Key Ayarlama

1. [Google AI Studio](https://aistudio.google.com/apikey) veya Google Cloud Console üzerinden bir API key alın.
2. Firebase Functions config'e ekleyin:

```bash
firebase functions:config:set gemini.apikey="BURAYA_API_KEY_YAPISTIRIN"
```

3. Functions'ı yeniden deploy edin:

```bash
firebase deploy --only functions
```

## Davranış

- **Key tanımlı:** Her yeni mesaj için Gemini'ye başlık + açıklama gönderilir; dönen kategori (elektronik, moda, ev_yasam, vb.) Firestore'a yazılır.
- **Key yok:** Eski mantık: anahtar kelime eşlemesi + uygulama kategori ID'sine çevirme (bilgisayar → elektronik, konsol_oyun → kitap_hobi vb.).

Uygulama tarafında kullandığınız Gemini key'i aynı key ile bu config'i de doldurabilirsiniz.
