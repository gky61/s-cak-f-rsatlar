#!/bin/bash
cd "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR"
pkill -9 -f flutter
pkill -9 -f dart
sleep 2
flutter clean
flutter pub get
flutter run -d emulator-5554







