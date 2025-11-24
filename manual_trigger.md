# Function'ı Manuel Tetikleme

## Yöntem 1: Firebase Console (En Kolay)

1. Firebase Console'a gidin: https://console.firebase.google.com/project/sicak-firsatlar-e6eae/functions
2. `fetchChannelMessages` function'ını bulun
3. "Test" sekmesine tıklayın
4. "Test the function" butonuna tıklayın
5. Logları kontrol edin

## Yöntem 2: gcloud CLI (Eğer yüklüyse)

```bash
gcloud pubsub topics publish firebase-schedule-fetchChannelMessages-us-central1 \
  --message '{"data":"manual"}' \
  --project sicak-firsatlar-e6eae
```

## Yöntem 3: Cloud Scheduler'dan

1. Google Cloud Console'a gidin
2. Cloud Scheduler'ı açın
3. `firebase-schedule-fetchChannelMessages-us-central1` job'ını bulun
4. "RUN NOW" butonuna tıklayın





