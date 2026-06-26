#!/usr/bin/env python3
"""
Son 1 saatte eklenen deals'leri kontrol et
"""
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta

# Firebase başlat
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate({
        "type": "service_account",
        "project_id": "sicak-firsatlar-e6eae",
        "private_key_id": "dummy",
        "private_key": "dummy",
        "client_email": "dummy@sicak-firsatlar-e6eae.iam.gserviceaccount.com",
        "client_id": "dummy",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs"
    })
    # Application Default Credentials kullan
    firebase_admin.initialize_app()

db = firestore.client()

# Son 1 saatte oluşturulan deals
one_hour_ago = datetime.now() - timedelta(hours=1)

print("🔍 Son 1 saatte eklenen fırsatlar:\n")

deals = db.collection('deals')\
    .where('source', '==', 'telegram')\
    .order_by('createdAt', direction=firestore.Query.DESCENDING)\
    .limit(10)\
    .stream()

count = 0
for deal in deals:
    data = deal.to_dict()
    count += 1
    print(f"{'='*60}")
    print(f"ID: {deal.id}")
    print(f"Başlık: {data.get('title', 'N/A')}")
    print(f"Link: {data.get('link', 'N/A')}")
    print(f"Fiyat: {data.get('price', 0)} TL")
    print(f"Kanal: {data.get('telegramChatTitle', 'N/A')}")
    print(f"Onay Durumu: {'✅ Onaylandı' if data.get('isApproved') else '⏳ Bekliyor'}")
    
    created_at = data.get('createdAt')
    if created_at:
        print(f"Tarih: {created_at}")
    
    raw_msg = data.get('rawMessage', '')
    if raw_msg:
        print(f"Orijinal Mesaj: {raw_msg[:100]}...")
    print()

if count == 0:
    print("❌ Hiç fırsat bulunamadı!")
else:
    print(f"\n✅ Toplam {count} fırsat bulundu")
