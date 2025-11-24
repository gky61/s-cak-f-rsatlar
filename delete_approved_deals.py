#!/usr/bin/env python3
"""
Onaylanmış fırsatları silme scripti
"""

import os
import sys
import firebase_admin
from firebase_admin import credentials, firestore
from dotenv import load_dotenv

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

def delete_approved_deals():
    """Onaylanmış ve onay bekleyen tüm fırsatları sil"""
    try:
        # Onaylanmış deal'leri getir
        print("🔍 Onaylanmış fırsatlar aranıyor...")
        approved_deals = db.collection('deals').where('isApproved', '==', True).get()
        approved_count = len(approved_deals)
        print(f"📊 {approved_count} adet onaylanmış fırsat bulundu")
        
        # Onay bekleyen deal'leri getir
        print("🔍 Onay bekleyen fırsatlar aranıyor...")
        pending_deals = db.collection('deals').where('isApproved', '==', False).get()
        pending_count = len(pending_deals)
        print(f"📊 {pending_count} adet onay bekleyen fırsat bulundu")
        
        total_count = approved_count + pending_count
        
        if total_count == 0:
            print("✅ Silinecek fırsat yok")
            return
        
        # Komut satırı argümanından onay al
        auto_confirm = len(sys.argv) > 1 and sys.argv[1] == '--yes'
        
        if not auto_confirm:
            print(f"\n⚠️  {total_count} adet fırsat silinecek!")
            print(f"   - {approved_count} adet onaylanmış")
            print(f"   - {pending_count} adet onay bekleyen")
            print("Otomatik silmek için: python delete_approved_deals.py --yes")
            return
        
        print(f"\n🗑️  {total_count} adet fırsat siliniyor...")
        print(f"   - {approved_count} adet onaylanmış")
        print(f"   - {pending_count} adet onay bekleyen")
        
        # Batch write ile sil (500'lük gruplar halinde)
        deleted_count = 0
        batch = db.batch()
        batch_count = 0
        
        # Önce onaylanmış deal'leri sil
        for deal in approved_deals:
            batch.delete(deal.reference)
            batch_count += 1
            deleted_count += 1
            
            # Her 500 deal'de bir batch commit et
            if batch_count >= 500:
                batch.commit()
                print(f"✅ {deleted_count}/{total_count} fırsat silindi...")
                batch = db.batch()
                batch_count = 0
        
        # Sonra onay bekleyen deal'leri sil
        for deal in pending_deals:
            batch.delete(deal.reference)
            batch_count += 1
            deleted_count += 1
            
            # Her 500 deal'de bir batch commit et
            if batch_count >= 500:
                batch.commit()
                print(f"✅ {deleted_count}/{total_count} fırsat silindi...")
                batch = db.batch()
                batch_count = 0
        
        # Kalan deal'leri sil
        if batch_count > 0:
            batch.commit()
        
        print(f"\n✅ Toplam {deleted_count} adet fırsat silindi")
        print(f"   - {approved_count} adet onaylanmış")
        print(f"   - {pending_count} adet onay bekleyen")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    delete_approved_deals()

