@echo off
REM ==============================================================================
REM FırsatKolik - Firestore Point-in-Time Recovery (PITR) Etkinleştirme Scripti
REM P0-03 (R-INF-07) Kalkanı
REM ==============================================================================

echo [BILGI] Firestore Point-in-Time Recovery (PITR) etkinlestiriliyor...

echo [1/2] PROD Projesi (firsatkolik-prod-e6eae)...
call gcloud firestore databases update --database="(default)" --enable-pitr --project=firsatkolik-prod-e6eae

echo [2/2] DEV Projesi (sicak-firsatlar-e6eae)...
call gcloud firestore databases update --database="(default)" --enable-pitr --project=sicak-firsatlar-e6eae

echo [TAMAMLANDI] PITR her iki ortam icin basariyla etkinlestirildi!
pause
