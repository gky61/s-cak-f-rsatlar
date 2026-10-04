#!/bin/bash
# ==============================================================================
# FırsatKolik - Firestore Point-in-Time Recovery (PITR) Etkinleştirme Scripti
# P0-03 (R-INF-07) Kalkanı
# ==============================================================================

echo "🛡️ Firestore Point-in-Time Recovery (PITR) etkinleştiriliyor..."

# 1. PROD Projesinde PITR Ac (7 gunluk veri kurtarma penceresi saglar)
echo "📦 PROD Projesi (firsatkolik-prod-e6eae)..."
gcloud firestore databases update --database='(default)' --enable-pitr --project=firsatkolik-prod-e6eae

# 2. DEV Projesinde PITR Ac
echo "📦 DEV Projesi (sicak-firsatlar-e6eae)..."
gcloud firestore databases update --database='(default)' --enable-pitr --project=sicak-firsatlar-e6eae

echo "✅ PITR her iki ortam için başarıyla etkinleştirildi!"
