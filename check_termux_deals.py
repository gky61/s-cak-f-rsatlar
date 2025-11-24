#!/usr/bin/env python3
"""
Termux'tan kaydedilen deal'leri kontrol etme scripti
Firebase REST API kullanarak kontrol eder
"""

import os
import sys
import json
from datetime import datetime
from dotenv import load_dotenv
from google.oauth2 import service_account
from google.auth.transport.requests import Request

# Environment variables
load_dotenv()

class FirebaseRestAPI:
    """Firebase REST API için helper sınıf"""
    
    def __init__(self, project_id: str, cred_path: str):
        self.project_id = project_id
        self.credentials = service_account.Credentials.from_service_account_file(
            cred_path,
            scopes=['https://www.googleapis.com/auth/datastore', 'https://www.googleapis.com/auth/cloud-platform']
        )
        self.request = Request()
        if self.credentials.project_id:
            self.project_id = self.credentials.project_id
    
    def _get_access_token(self):
        """Geçerli access token döndür"""
        if not self.credentials.valid or self.credentials.expired:
            self.credentials.refresh(self.request)
        return self.credentials.token
    
    def firestore_query(self, collection: str, filters: list = None, limit: int = 50) -> list:
        """Firestore'dan sorgu yap"""
        import requests
        token = self._get_access_token()
        url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents:runQuery"
        
        # Query oluştur
        structured_query = {
            'from': [{'collectionId': collection}],
            'limit': limit
        }
        
        if filters:
            field_filters = []
            for filter_item in filters:
                field_name = filter_item[0]
                operator = filter_item[1] if len(filter_item) > 1 else 'EQUAL'
                value = filter_item[2] if len(filter_item) > 2 else None
                
                if value is None:
                    continue
                
                if isinstance(value, bool):
                    firestore_value = {'booleanValue': value}
                elif isinstance(value, int):
                    firestore_value = {'integerValue': str(value)}
                elif isinstance(value, float):
                    firestore_value = {'doubleValue': value}
                elif isinstance(value, str):
                    try:
                        int_value = int(value)
                        firestore_value = {'integerValue': str(int_value)}
                    except ValueError:
                        firestore_value = {'stringValue': value}
                else:
                    firestore_value = {'stringValue': str(value)}
                
                field_filters.append({
                    'fieldFilter': {
                        'field': {'fieldPath': field_name},
                        'op': operator,
                        'value': firestore_value
                    }
                })
            
            if field_filters:
                if len(field_filters) == 1:
                    # Tek filter varsa compositeFilter yerine direkt fieldFilter kullan
                    structured_query['where'] = field_filters[0]['fieldFilter']
                else:
                    # Birden fazla filter varsa compositeFilter kullan
                    structured_query['where'] = {
                        'compositeFilter': {
                            'op': 'AND',
                            'filters': field_filters
                        }
                    }
        
        query = {'structuredQuery': structured_query}
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        # Debug: Query'yi yazdır
        import json as json_module
        print(f"🔍 Debug Query: {json_module.dumps(query, indent=2)}")
        
        response = requests.post(url, json=query, headers=headers)
        if response.status_code == 200:
            results = response.json()
            return [r for r in results if 'document' in r]
        else:
            raise Exception(f"Firestore sorgu hatası: {response.status_code} - {response.text}")

def check_termux_deals():
    """Termux'tan kaydedilen deal'leri kontrol et"""
    try:
        print("🔍 Termux'tan kaydedilen deal'ler kontrol ediliyor...\n")
        
        # Firebase başlatma
        cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'firebase_key.json')
        if not os.path.exists(cred_path):
            print(f"❌ Firebase credentials not found at {cred_path}")
            sys.exit(1)
        
        with open(cred_path, 'r') as f:
            cred_data = json.load(f)
            project_id = cred_data.get('project_id', 'sicak-firsatlar-e6eae')
        
        firebase_api = FirebaseRestAPI(project_id, cred_path)
        
        # Onay bekleyen deal'leri getir
        print("📊 Onay bekleyen deal'ler sorgulanıyor...")
        filters = [
            ('isApproved', 'EQUAL', False),
        ]
        results = firebase_api.firestore_query('deals', filters=filters, limit=20)
        
        print(f"\n📱 Toplam {len(results)} deal bulundu\n")
        
        telegram_deals = []
        for result in results:
            doc = result.get('document', {})
            doc_id = doc.get('name', '').split('/')[-1]
            fields = doc.get('fields', {})
            
            # Alanları parse et
            title = fields.get('title', {}).get('stringValue', 'Başlık yok')
            is_approved = fields.get('isApproved', {}).get('booleanValue', False)
            is_expired = fields.get('isExpired', {}).get('booleanValue', False)
            source = fields.get('source', {}).get('stringValue', 'unknown')
            created_at = fields.get('createdAt', {})
            
            # createdAt'i parse et
            created_at_str = 'Bilinmiyor'
            if 'timestampValue' in created_at:
                created_at_str = created_at['timestampValue']
            elif 'stringValue' in created_at:
                created_at_str = created_at['stringValue']
            
            deal_info = {
                'id': doc_id,
                'title': title[:50],
                'source': source,
                'isApproved': is_approved,
                'isExpired': is_expired,
                'createdAt': created_at_str,
            }
            
            if source == 'telegram':
                telegram_deals.append(deal_info)
            
            print(f"📋 Deal ID: {doc_id}")
            print(f"   Başlık: {title[:60]}")
            print(f"   Source: {source}")
            print(f"   isApproved: {is_approved}")
            print(f"   isExpired: {is_expired}")
            print(f"   createdAt: {created_at_str}")
            print(f"   createdAt tipi: {type(created_at)}")
            print()
        
        print(f"\n📱 Telegram'dan çekilen deal'ler: {len(telegram_deals)}")
        print(f"⏳ Onay bekleyen deal'ler: {len([d for d in telegram_deals if not d['isApproved'] and not d['isExpired']])}")
        
        # Sorunlu deal'leri göster
        problematic = []
        for deal in telegram_deals:
            if not deal['isApproved'] and not deal['isExpired']:
                if deal['createdAt'] == 'Bilinmiyor' or 'timestampValue' not in str(deal['createdAt']):
                    problematic.append(deal)
        
        if problematic:
            print(f"\n⚠️ Sorunlu deal'ler (createdAt formatı yanlış): {len(problematic)}")
            for deal in problematic:
                print(f"   - {deal['title']} | ID: {deal['id']} | createdAt: {deal['createdAt']}")
        
    except Exception as e:
        print(f"❌ Hata: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    check_termux_deals()

