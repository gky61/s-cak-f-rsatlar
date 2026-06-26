#!/usr/bin/env python3
"""
Firebase'deki deal'lerin imageUrl'lerini kontrol et
"""

import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore

# Firebase initialization
if not firebase_admin._apps:
    # Google Cloud ortamında Application Default Credentials kullan
    try:
        firebase_admin.initialize_app()
        print("✅ Firebase Admin SDK başlatıldı (ADC)")
    except Exception as e:
        print(f"❌ Firebase başlatılamadı: {e}")
        sys.exit(1)

db = firestore.client()

def check_image_urls():
    """Son deal'lerin imageUrl'lerini kontrol et"""
    try:
        print("🔍 Son deal'lerin imageUrl'leri kontrol ediliyor...\n")
        
        # Son 10 deal'i getir
        deals = db.collection('deals').order_by('createdAt', direction=firestore.Query.DESCENDING).limit(10).get()
        
        print(f"📊 Son 10 deal:\n")
        for deal in deals:
            data = deal.to_dict()
            doc_id = deal.id
            title = data.get('title', 'Başlık yok')[:50]
            image_url = data.get('imageUrl', None)
            source = data.get('source', 'unknown')
            telegram_msg_id = data.get('telegramMessageId', 'N/A')
            
            # ImageUrl var mı kontrol et
            if image_url:
                # Firebase Storage path'ini çıkar
                if 'deals%2F' in image_url or 'deals/' in image_url:
                    # Dosya adını al
                    if 'deals%2F' in image_url:
                        filename = image_url.split('deals%2F')[1].split('?')[0]
                    else:
                        filename = image_url.split('deals/')[1].split('?')[0]
                    print(f"✅ ID: {doc_id}")
                    print(f"   Title: {title}")
                    print(f"   Source: {source} | TelegramID: {telegram_msg_id}")
                    print(f"   📸 Image: {filename}")
                else:
                    print(f"⚠️  ID: {doc_id}")
                    print(f"   Title: {title}")
                    print(f"   Source: {source}")
                    print(f"   📸 Image URL (harici): {image_url[:80]}...")
            else:
                print(f"❌ ID: {doc_id}")
                print(f"   Title: {title}")
                print(f"   Source: {source} | TelegramID: {telegram_msg_id}")
                print(f"   📸 Image: YOK!")
            print()
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    check_image_urls()
