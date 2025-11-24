#!/usr/bin/env python3
"""
Firebase'deki deal'leri kontrol etme scripti
"""

import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv
from datetime import datetime, timedelta

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

def check_firebase_deals():
    """Firebase'deki deal'leri kontrol et"""
    try:
        print("🔍 Firebase'deki deal'ler kontrol ediliyor...\n")
        
        # Son 24 saatte eklenen deal'leri getir
        yesterday = datetime.utcnow() - timedelta(days=1)
        
        # Tüm deal'leri getir (son 24 saat)
        print("📊 Son 24 saatte eklenen deal'ler:")
        all_deals = db.collection('deals').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(20).get()
        
        telegram_deals = []
        approved_deals = []
        pending_deals = []
        
        for deal in all_deals:
            data = deal.to_dict()
            source = data.get('source', 'unknown')
            is_approved = data.get('isApproved', False)
            is_expired = data.get('isExpired', False)
            created_at = data.get('createdAt')
            title = data.get('title', 'Başlık yok')[:50]
            
            deal_info = {
                'id': deal.id,
                'title': title,
                'source': source,
                'isApproved': is_approved,
                'isExpired': is_expired,
                'createdAt': created_at,
                'telegramMessageId': data.get('telegramMessageId'),
            }
            
            if source == 'telegram':
                telegram_deals.append(deal_info)
            
            if is_approved:
                approved_deals.append(deal_info)
            else:
                pending_deals.append(deal_info)
        
        print(f"\n📱 Telegram'dan çekilen deal'ler: {len(telegram_deals)}")
        for deal in telegram_deals[:10]:  # İlk 10'unu göster
            status = "✅ Onaylı" if deal['isApproved'] else "⏳ Bekliyor"
            expired = "❌ Expired" if deal['isExpired'] else "✅ Aktif"
            print(f"   - {deal['title']} | {status} | {expired} | ID: {deal['id']}")
        
        print(f"\n✅ Onaylanmış deal'ler: {len(approved_deals)}")
        print(f"⏳ Onay bekleyen deal'ler: {len(pending_deals)}")
        
        # Onay bekleyen Telegram deal'lerini göster
        telegram_pending = [d for d in telegram_deals if not d['isApproved'] and not d['isExpired']]
        print(f"\n📱 Onay bekleyen Telegram deal'leri: {len(telegram_pending)}")
        for deal in telegram_pending[:10]:
            print(f"   - {deal['title']} | MessageID: {deal.get('telegramMessageId', 'N/A')} | ID: {deal['id']}")
        
        # Son 1 saatte eklenen deal'leri kontrol et
        one_hour_ago = datetime.utcnow() - timedelta(hours=1)
        recent_deals = []
        for deal in all_deals:
            data = deal.to_dict()
            created_at = data.get('createdAt')
            if created_at:
                if isinstance(created_at, datetime):
                    if created_at > one_hour_ago:
                        recent_deals.append(deal)
                elif hasattr(created_at, 'timestamp'):
                    if created_at.timestamp() > one_hour_ago.timestamp():
                        recent_deals.append(deal)
        
        print(f"\n⏰ Son 1 saatte eklenen deal'ler: {len(recent_deals)}")
        for deal in recent_deals[:5]:
            data = deal.to_dict()
            print(f"   - {data.get('title', 'Başlık yok')[:50]} | Source: {data.get('source', 'unknown')} | Approved: {data.get('isApproved', False)}")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    check_firebase_deals()




