#!/usr/bin/env python3
"""
Firebase'deki deal'leri detaylı kontrol etme scripti
"""

import os
import sys
import json
from datetime import datetime
from dotenv import load_dotenv

# Environment variables
load_dotenv()

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    USE_FIREBASE_ADMIN = True
except ImportError:
    USE_FIREBASE_ADMIN = False
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request
    import requests

def debug_firebase_deals():
    """Firebase'deki deal'leri detaylı kontrol et"""
    try:
        print("🔍 Firebase'deki deal'ler detaylı kontrol ediliyor...\n")
        
        # Firebase başlatma
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'firebase_key.json')
        if not os.path.exists(cred_path):
            print(f"❌ Firebase credentials not found at {cred_path}")
            sys.exit(1)
        
        if USE_FIREBASE_ADMIN:
            if not firebase_admin._apps:
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
            db = firestore.client()
            
            # Son 20 deal'i getir
            print("📊 Son 20 deal getiriliyor...\n")
            deals = db.collection('deals').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(20).get()
            
            telegram_deals = []
            pending_deals = []
            
            for deal in deals:
                data = deal.to_dict()
                doc_id = deal.id
                
                # Alanları kontrol et
                title = data.get('title', 'Başlık yok')[:50]
                is_approved = data.get('isApproved')
                is_expired = data.get('isExpired')
                source = data.get('source', 'unknown')
                created_at = data.get('createdAt')
                posted_by = data.get('postedBy', '')
                
                # createdAt tipini kontrol et
                created_at_type = type(created_at).__name__
                created_at_str = str(created_at)
                
                deal_info = {
                    'id': doc_id,
                    'title': title,
                    'source': source,
                    'isApproved': is_approved,
                    'isApproved_type': type(is_approved).__name__,
                    'isExpired': is_expired,
                    'isExpired_type': type(is_expired).__name__,
                    'createdAt': created_at_str,
                    'createdAt_type': created_at_type,
                    'postedBy': posted_by,
                }
                
                if source == 'telegram':
                    telegram_deals.append(deal_info)
                
                if is_approved == False or is_approved is None:
                    if is_expired != True:
                        pending_deals.append(deal_info)
                
                print(f"📋 Deal ID: {doc_id}")
                print(f"   Başlık: {title}")
                print(f"   Source: {source}")
                print(f"   isApproved: {is_approved} (tip: {type(is_approved).__name__})")
                print(f"   isExpired: {is_expired} (tip: {type(is_expired).__name__})")
                print(f"   createdAt: {created_at_str} (tip: {created_at_type})")
                print(f"   postedBy: {posted_by}")
                print()
            
            print(f"\n📱 Telegram'dan çekilen deal'ler: {len(telegram_deals)}")
            print(f"⏳ Onay bekleyen deal'ler: {len(pending_deals)}")
            
            # Onay bekleyen Telegram deal'lerini göster
            telegram_pending = [d for d in telegram_deals if (d['isApproved'] == False or d['isApproved'] is None) and d['isExpired'] != True]
            print(f"\n📱 Onay bekleyen Telegram deal'leri: {len(telegram_pending)}")
            for deal in telegram_pending[:10]:
                print(f"   - {deal['title']} | ID: {deal['id']}")
                print(f"     isApproved: {deal['isApproved']} ({deal['isApproved_type']})")
                print(f"     isExpired: {deal['isExpired']} ({deal['isExpired_type']})")
                print(f"     createdAt: {deal['createdAt_type']}")
            
            # Sorunlu deal'leri göster
            problematic = []
            for deal in telegram_pending:
                issues = []
                if deal['isApproved_type'] not in ['bool', 'NoneType']:
                    issues.append(f"isApproved tipi yanlış: {deal['isApproved_type']}")
                if deal['isExpired_type'] not in ['bool', 'NoneType']:
                    issues.append(f"isExpired tipi yanlış: {deal['isExpired_type']}")
                if deal['createdAt_type'] not in ['Timestamp', 'datetime']:
                    issues.append(f"createdAt tipi yanlış: {deal['createdAt_type']}")
                if issues:
                    problematic.append((deal, issues))
            
            if problematic:
                print(f"\n⚠️ Sorunlu deal'ler: {len(problematic)}")
                for deal, issues in problematic[:5]:
                    print(f"   - {deal['title']} | ID: {deal['id']}")
                    for issue in issues:
                        print(f"     ❌ {issue}")
            else:
                print("\n✅ Tüm deal'ler doğru formatta görünüyor!")
                
        else:
            print("⚠️ firebase-admin yüklü değil, REST API kullanılamıyor")
            print("Lütfen: pip install firebase-admin")
            
    except Exception as e:
        print(f"❌ Hata: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    debug_firebase_deals()


