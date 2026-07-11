@echo off
echo 🚀 FirsatKolik DEV Release APK Derlemesi Basliyor...
cd ..
call flutter clean
call flutter pub get
call flutter build apk --release --flavor dev --dart-define=FLAVOR=dev
echo.
echo ✅ Derleme Tamamlandi! Dosya konumu: build\app\outputs\flutter-apk\app-dev-release.apk
pause
