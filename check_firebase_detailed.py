#!/usr/bin/env python3
"""
Firebase'deki deal'lerin detaylı kontrolü
"""

import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
import json

# Environment variables
load_dotenv()

# Firebase initialization
if not firebase_admin._apps:
    cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'firebase_key.json')
    if os.path.exists(cred_path):
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    else:
        print(f"❌ Firebase credentials not found at {cred_path}")
        sys.exit(1)

db = firestore.client()

def check_detailed():
    """Detaylı kontrol"""
    try:
        print("🔍 Firebase'deki deal'lerin detaylı kontrolü...\n")
        
        # Onay bekleyen deal'leri getir (Flutter'ın yaptığı query gibi)
        print("📊 isApproved == false olan deal'ler:")
        pending_query = db.collection('deals').where('isApproved', '==', False).limit(20).get()
        
        print(f"✅ Toplam {len(pending_query)} adet deal bulundu\n")
        
        for i, deal in enumerate(pending_query, 1):
            data = deal.to_dict()
            print(f"{i}. Deal ID: {deal.id}")
            print(f"   Başlık: {data.get('title', 'N/A')[:60]}")
            print(f"   isApproved: {data.get('isApproved')} (tip: {type(data.get('isApproved'))})")
            print(f"   isExpired: {data.get('isExpired')} (tip: {type(data.get('isExpired'))})")
            print(f"   source: {data.get('source', 'N/A')}")
            print(f"   telegramMessageId: {data.get('telegramMessageId', 'N/A')}")
            print(f"   createdAt: {data.get('createdAt', 'N/A')}")
            print()
        
        # Tüm deal'leri kontrol et (isApproved field'ı olmayanlar)
        print("\n📊 isApproved field'ı olmayan deal'ler:")
        all_deals = db.collection('deals').limit(50).get()
        no_approved_field = []
        for deal in all_deals:
            data = deal.to_dict()
            if 'isApproved' not in data:
                no_approved_field.append(deal.id)
                print(f"   - {deal.id}: {data.get('title', 'N/A')[:50]}")
        
        if not no_approved_field:
            print("   ✅ Tüm deal'lerde isApproved field'ı var")
        
        # isApproved == null olanlar
        print("\n📊 isApproved == null olan deal'ler:")
        null_approved = []
        for deal in all_deals:
            data = deal.to_dict()
            if data.get('isApproved') is None:
                null_approved.append(deal.id)
                print(f"   - {deal.id}: {data.get('title', 'N/A')[:50]}")
        
        if not null_approved:
            print("   ✅ isApproved == null olan deal yok")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    check_detailed()




