@echo off
echo 🚀 FirsatKolik PROD Release AAB Derlemesi Basliyor...
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
echo ✅ Derleme Tamamlandi! Dosya konumu: build\app\outputs\bundle\prodRelease\app-prod-release.aab
pause
