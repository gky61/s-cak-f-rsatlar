#!/usr/bin/env python3
"""
Telegram Bot - Görsel ve Veri Çekme
Telegram kanallarından/gruplarından fırsat paylaşımlarını çeker,
görselleri ve fiyatları işler, Firebase'e kaydeder.
"""

import os
import re
import json
import asyncio
import logging
from datetime import datetime
from typing import Optional, Dict, List
from urllib.parse import urlparse, urljoin

# Telegram
from telethon import TelegramClient, events
from telethon.tl.types import MessageMediaPhoto, MessageMediaDocument
from telethon.errors import SessionPasswordNeededError

# Firebase - Hibrit yaklaşım (firebase-admin varsa onu kullan, yoksa REST API)
USE_FIREBASE_ADMIN = False
try:
    import firebase_admin
    from firebase_admin import credentials, firestore, storage, messaging
    USE_FIREBASE_ADMIN = True
    logger_temp = None  # Logger henüz tanımlı değil
except ImportError:
    # firebase-admin yok, REST API kullanacağız
    USE_FIREBASE_ADMIN = False
    import requests
    from google.oauth2 import service_account
    from google.auth.transport.requests import Request

# HTML Parsing
from bs4 import BeautifulSoup
import aiohttp
from curl_cffi.requests import AsyncSession  # curl_cffi ile tarayıcı taklidi
import google.generativeai as genai  # Gemini AI

# Environment variables
from dotenv import load_dotenv

# Logs klasörünü oluştur
os.makedirs('logs', exist_ok=True)

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('logs/telegram_bot.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Gemini AI Setup
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    # Model tanımlama - gemini-pro artık kullanılamıyor, gemini-1.5-flash veya gemini-1.5-pro kullan
    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
        logger.info("✅ Gemini model yüklendi: gemini-1.5-flash")
    except Exception as e:
        logger.warning(f"⚠️ Gemini model yüklenemedi: {e}. gemini-1.5-pro deneniyor...")
        try:
            model = genai.GenerativeModel('gemini-1.5-pro')
            logger.info("✅ Gemini model yüklendi: gemini-1.5-pro")
        except Exception as e2:
            logger.error(f"❌ Gemini model yüklenemedi: {e2}")
            model = None
else:
    logger.warning("⚠️ GEMINI_API_KEY bulunamadı! Akıllı analiz çalışmayacak.")
    model = None

# Firebase initialization
project_id = 'sicak-firsatlar-e6eae'  # Varsayılan değer
db = None
bucket = None
firebase_rest_api = None

# Firebase REST API Helper Class
class FirebaseRestAPI:
    """Firebase REST API için helper sınıf"""
    def __init__(self, project_id: str, cred_path: str):
        self.project_id = project_id
        self.cred_path = cred_path
        self.scopes = [
            'https://www.googleapis.com/auth/cloud-platform',
            'https://www.googleapis.com/auth/datastore',
            'https://www.googleapis.com/auth/devstorage.full_control'
        ]
        self.credentials = service_account.Credentials.from_service_account_file(
            cred_path,
            scopes=self.scopes
        )
        self.request = Request()
        if self.credentials.project_id:
            self.project_id = self.credentials.project_id
    
    def _get_access_token(self):
        """Geçerli access token döndür"""
        if not self.credentials.valid or self.credentials.expired:
            self.credentials.refresh(self.request)
        return self.credentials.token
    
    def firestore_add(self, collection: str, data: dict) -> str:
        """Firestore'a doküman ekle"""
        token = self._get_access_token()
        url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents/{collection}"
        
        # Firestore formatına çevir
        fields = {}
        for key, value in data.items():
            if value is None:
                continue
            elif isinstance(value, bool):
                fields[key] = {'booleanValue': value}
            elif isinstance(value, int):
                fields[key] = {'integerValue': str(value)}
            elif isinstance(value, float):
                fields[key] = {'doubleValue': value}
            elif isinstance(value, str):
                fields[key] = {'stringValue': value}
            elif isinstance(value, list):
                fields[key] = {'arrayValue': {'values': [{'stringValue': str(v)} for v in value]}}
            elif isinstance(value, datetime):
                # Datetime objelerini Firestore Timestamp formatına çevir
                fields[key] = {'timestampValue': value.isoformat() + 'Z'}
            elif hasattr(value, '__name__') and value.__name__ == 'SERVER_TIMESTAMP':
                fields[key] = {'timestampValue': datetime.utcnow().isoformat() + 'Z'}
            else:
                fields[key] = {'stringValue': str(value)}
        
        payload = {'fields': fields}
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(url, json=payload, headers=headers)
        if response.status_code == 200:
            result = response.json()
            return result['name'].split('/')[-1]  # Document ID
        else:
            raise Exception(f"Firestore ekleme hatası: {response.status_code} - {response.text}")
    
    def firestore_update(self, collection: str, doc_id: str, data: dict):
        """Firestore'da doküman güncelle"""
        token = self._get_access_token()
        url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents/{collection}/{doc_id}"
        
        # Firestore formatına çevir
        fields = {}
        for key, value in data.items():
            if value is None:
                continue
            elif isinstance(value, bool):
                fields[key] = {'booleanValue': value}
            elif isinstance(value, int):
                fields[key] = {'integerValue': str(value)}
            elif isinstance(value, float):
                fields[key] = {'doubleValue': value}
            elif isinstance(value, str):
                fields[key] = {'stringValue': value}
            elif isinstance(value, list):
                fields[key] = {'arrayValue': {'values': [{'stringValue': str(v)} for v in value]}}
            elif isinstance(value, datetime):
                fields[key] = {'timestampValue': value.isoformat() + 'Z'}
            elif hasattr(value, '__name__') and value.__name__ == 'SERVER_TIMESTAMP':
                fields[key] = {'timestampValue': datetime.utcnow().isoformat() + 'Z'}
            else:
                fields[key] = {'stringValue': str(value)}
        
        payload = {'fields': fields}
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.patch(url, json=payload, headers=headers)
        if response.status_code == 200:
            return True
        else:
            raise Exception(f"Firestore güncelleme hatası: {response.status_code} - {response.text}")
    
    def firestore_query(self, collection: str, filters: list = None, limit: int = 1) -> list:
        """Firestore'dan sorgu yap - DÜZELTİLMİŞ VERSİYON"""
        token = self._get_access_token()
        url = f"https://firestore.googleapis.com/v1/projects/{self.project_id}/databases/(default)/documents:runQuery"
        
        # Query oluştur
        structured_query = {
            'from': [{'collectionId': collection}],
            'limit': limit
        }
        
        if filters:
            # Filter'ları Firestore formatına çevir
            field_filters = []
            for filter_item in filters:
                field_name = filter_item[0]  # Örn: 'telegramMessageId'
                operator = filter_item[1] if len(filter_item) > 1 else 'EQUAL'  # Örn: 'EQUAL'
                value = filter_item[2] if len(filter_item) > 2 else None  # Değer
                
                if value is None:
                    continue
                
                # Değer tipine göre Firestore value formatını belirle
                if isinstance(value, bool):
                    firestore_value = {'booleanValue': value}
                elif isinstance(value, int):
                    firestore_value = {'integerValue': str(value)}
                elif isinstance(value, float):
                    firestore_value = {'doubleValue': value}
                elif isinstance(value, str):
                    # Eğer string bir sayıysa, integer'a çevirmeyi dene
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
        
        # Ana query objesi
        query = {
            'structuredQuery': structured_query
        }
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        response = requests.post(url, json=query, headers=headers)
        if response.status_code == 200:
            results = response.json()
            return [r for r in results if 'document' in r]
        else:
            raise Exception(f"Firestore sorgu hatası: {response.status_code} - {response.text}")
    
    def storage_upload(self, bucket_name: str, file_path: str, file_data: bytes, content_type: str = 'image/jpeg') -> str:
        """Firebase Storage'a dosya yükle"""
        token = self._get_access_token()
        # URL encode file path
        from urllib.parse import quote
        encoded_path = quote(file_path, safe='')
        url = f"https://storage.googleapis.com/upload/storage/v1/b/{bucket_name}/o?uploadType=media&name={encoded_path}"
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': content_type
        }
        
        response = requests.post(url, data=file_data, headers=headers)
        if response.status_code == 200:
            # Public yap
            public_url = f"https://storage.googleapis.com/{bucket_name}/{file_path}"
            self._make_public(bucket_name, file_path, token)
            return public_url
        else:
            raise Exception(f"Storage yükleme hatası: {response.status_code} - {response.text}")
    
    def _make_public(self, bucket_name: str, file_path: str, token: str):
        """Dosyayı public yap"""
        from urllib.parse import quote
        encoded_path = quote(file_path, safe='')
        url = f"https://storage.googleapis.com/storage/v1/b/{bucket_name}/o/{encoded_path}/acl"
        
        payload = {
            'entity': 'allUsers',
            'role': 'READER'
        }
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        
        requests.post(url, json=payload, headers=headers)

    def send_fcm_notification(self, topic: str, title: str, body: str, data: dict = None):
        """FCM üzerinden bildirim gönder (V1 API)"""
        try:
            token = self._get_access_token()
            url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
            
            # Topic adı düzeltme
            safe_topic = re.sub(r'[^a-zA-Z0-9-_.~%]', '_', topic)
            
            message = {
                "message": {
                    "topic": safe_topic,
                    "notification": {
                        "title": title,
                        "body": body
                    },
                    "data": data or {},
                    "android": {
                        "priority": "HIGH",
                        "notification": {
                            "sound": "default",
                            "channel_id": "deals_channel"
                        }
                    },
                    "apns": {
                        "payload": {
                            "aps": {
                                "sound": "default"
                            }
                        }
                    }
                }
            }
            
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.post(url, json=message, headers=headers)
            if response.status_code == 200:
                logging.info(f"✅ Bildirim gönderildi ({safe_topic}): {title}")
                return True
            else:
                logging.error(f"❌ Bildirim gönderme hatası: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            logging.error(f"❌ Bildirim istisna hatası: {e}")
            return False

    def send_fcm_notification(self, topic: str, title: str, body: str, data: dict = None):
        """FCM üzerinden bildirim gönder (V1 API)"""
        try:
            token = self._get_access_token()
            url = f"https://fcm.googleapis.com/v1/projects/{self.project_id}/messages:send"
            
            # Topic adı düzeltme (özel karakterlerden arındır)
            safe_topic = re.sub(r'[^a-zA-Z0-9-_.~%]', '_', topic)
            
            message = {
                "message": {
                    "topic": safe_topic,
                    "notification": {
                        "title": title,
                        "body": body
                    },
                    "data": data or {},
                    "android": {
                        "priority": "HIGH",
                        "notification": {
                            "sound": "default",
                            "channel_id": "deals_channel"
                        }
                    },
                    "apns": {
                        "payload": {
                            "aps": {
                                "sound": "default"
                            }
                        }
                    }
                }
            }
            
            headers = {
                'Authorization': f'Bearer {token}',
                'Content-Type': 'application/json'
            }
            
            response = requests.post(url, json=message, headers=headers)
            if response.status_code == 200:
                logger.info(f"✅ Bildirim gönderildi ({safe_topic}): {title}")
                return True
            else:
                logger.error(f"❌ Bildirim gönderme hatası: {response.status_code} - {response.text}")
                return False
        except Exception as e:
            logger.error(f"❌ Bildirim istisna hatası: {e}")
            return False

# Firebase başlatma
cred_path = os.getenv('FIREBASE_CREDENTIALS_PATH', 'firebase_key.json')
if not os.path.exists(cred_path):
    logger.error(f"Firebase credentials not found at {cred_path}")
    raise FileNotFoundError(f"Firebase credentials not found at {cred_path}")

# Credentials'dan project_id'yi al
with open(cred_path, 'r') as f:
    cred_data = json.load(f)
    project_id = cred_data.get('project_id', 'sicak-firsatlar-e6eae')
    storage_bucket_name = f"{project_id}.firebasestorage.app"

if USE_FIREBASE_ADMIN:
    # firebase-admin kullan (PC için)
    if not firebase_admin._apps:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred, {
            'storageBucket': storage_bucket_name
        })
        logger.info(f"✅ Firebase başlatıldı (firebase-admin - Storage: {storage_bucket_name})")
    
    db = firestore.client()
    
    try:
        bucket = storage.bucket(storage_bucket_name)
        if not bucket.exists():
            logger.warning(f"⚠️ Bucket {storage_bucket_name} bulunamadı, oluşturuluyor...")
            try:
                bucket.create()
                logger.info(f"✅ Bucket {storage_bucket_name} oluşturuldu")
            except Exception as create_error:
                logger.error(f"❌ Bucket oluşturma hatası: {create_error}")
                logger.warning("⚠️ Bucket oluşturulamadı, görsel yükleme çalışmayabilir")
        else:
            logger.info(f"✅ Bucket {storage_bucket_name} mevcut")
    except Exception as e:
        logger.error(f"❌ Bucket hatası: {e}")
        try:
            bucket = storage.bucket()
            logger.warning("⚠️ Varsayılan bucket kullanılıyor")
        except Exception as fallback_error:
            logger.error(f"❌ Varsayılan bucket da kullanılamıyor: {fallback_error}")
            bucket = None
else:
    # Firebase REST API kullan (Termux için)
    firebase_rest_api = FirebaseRestAPI(project_id, cred_path)
    logger.info(f"✅ Firebase başlatıldı (REST API - Storage: {storage_bucket_name})")


class TelegramDealBot:
    """Telegram'dan fırsat paylaşımlarını çeken bot"""

    def __init__(self):
        self.api_id = int(os.getenv('TELEGRAM_API_ID'))
        self.api_hash = os.getenv('TELEGRAM_API_HASH')
        self.session_name = os.getenv('TELEGRAM_SESSION_NAME', 'telegram_session')
        self.channels = os.getenv('TELEGRAM_CHANNELS', '').split(',')
        self.client = None
    
    def get_last_processed_message_id(self, chat_identifier: str) -> Optional[int]:
        """Firebase'den son işlenen mesaj ID'sini al"""
        try:
            if USE_FIREBASE_ADMIN:
                # firebase-admin kullan (PC için)
                doc_ref = db.collection('bot_state').document(chat_identifier)
                doc = doc_ref.get()
                if doc.exists:
                    data = doc.to_dict()
                    return data.get('lastMessageId')
            else:
                # Firebase REST API kullan (Termux için)
                results = firebase_rest_api.firestore_query(
                    'bot_state',
                    filters=[('chatIdentifier', 'EQUAL', chat_identifier)],
                    limit=1
                )
                if results and len(results) > 0:
                    doc = results[0].get('document', {})
                    fields = doc.get('fields', {})
                    last_id_field = fields.get('lastMessageId', {})
                    if 'integerValue' in last_id_field:
                        return int(last_id_field['integerValue'])
                    elif 'stringValue' in last_id_field:
                        return int(last_id_field['stringValue'])
            return None
        except Exception as e:
            logger.warning(f"Son mesaj ID'si alınamadı ({chat_identifier}): {e}")
            return None
    
    def save_last_processed_message_id(self, chat_identifier: str, message_id: int):
        """Firebase'e son işlenen mesaj ID'sini kaydet"""
        try:
            state_data = {
                'chatIdentifier': chat_identifier,
                'lastMessageId': message_id,
                'lastUpdated': datetime.utcnow(),
            }
            
            if USE_FIREBASE_ADMIN:
                # firebase-admin kullan (PC için)
                doc_ref = db.collection('bot_state').document(chat_identifier)
                doc_ref.set(state_data, merge=True)
            else:
                # Firebase REST API kullan (Termux için)
                # Önce mevcut dokümanı kontrol et
                existing = firebase_rest_api.firestore_query(
                    'bot_state',
                    filters=[('chatIdentifier', 'EQUAL', chat_identifier)],
                    limit=1
                )
                
                if existing and len(existing) > 0:
                    # Güncelle
                    doc_id = existing[0]['document']['name'].split('/')[-1]
                    firebase_rest_api.firestore_update('bot_state', doc_id, state_data)
                else:
                    # Yeni oluştur
                    firebase_rest_api.firestore_add('bot_state', state_data)
            
            logger.info(f"✅ Son mesaj ID kaydedildi: {chat_identifier} -> {message_id}")
        except Exception as e:
            logger.error(f"❌ Son mesaj ID kaydedilemedi ({chat_identifier}): {e}")

    async def initialize(self):
        """Telegram client'ı başlat"""
        self.client = TelegramClient(
            self.session_name,
            self.api_id,
            self.api_hash,
            timeout=30,
            retry_delay=2,
            auto_reconnect=True
        )
        await self.client.start()
        logger.info("✅ Telegram Client başlatıldı")

    async def fetch_image_from_telegram(self, message, chat_identifier: str, message_id: int) -> Optional[str]:
        """Telegram media'dan görsel çek ve Firebase Storage'a yükle"""
        if not message.media:
            return None

        if isinstance(message.media, MessageMediaPhoto):
            try:
                logger.info(f"📷 Telegram görsel indiriliyor (Message {message_id})...")
                
                # Görseli indir
                image_bytes = await self.client.download_media(message, file=bytes)
                
                if not image_bytes or len(image_bytes) < 1024:  # Minimum 1KB
                    logger.warning("⚠️ Görsel çok küçük veya geçersiz")
                    return None

                # Firebase Storage'a yükle
                timestamp = int(datetime.now().timestamp() * 1000)
                file_name = f"telegram/{chat_identifier}/{message_id}_{timestamp}.jpg"
                
                if USE_FIREBASE_ADMIN:
                    # firebase-admin kullan (PC için)
                    if bucket is None:
                        logger.error("❌ Bucket mevcut değil, görsel yüklenemiyor")
                        return None
                    
                    blob = bucket.blob(file_name)
                    blob.upload_from_string(
                        image_bytes,
                        content_type='image/jpeg'
                    )
                    # Metadata'yı ayrı olarak ayarla
                    blob.metadata = {
                        'source': 'telegram',
                        'messageId': str(message_id),
                        'channel': chat_identifier,
                        'timestamp': str(timestamp)
                    }
                    blob.patch()
                    blob.make_public()
                    image_url = f"https://storage.googleapis.com/{bucket.name}/{file_name}"
                else:
                    # Firebase REST API kullan (Termux için)
                    image_url = firebase_rest_api.storage_upload(
                        storage_bucket_name,
                        file_name,
                        image_bytes,
                        'image/jpeg'
                    )
                
                logger.info(f"✅ Telegram görsel yüklendi: {image_url} ({len(image_bytes)} bytes)")
                return image_url

            except Exception as e:
                logger.error(f"❌ Telegram görsel yükleme hatası: {e}")
                return None

        return None

    async def fetch_link_data(self, url: str, retries: int = 2) -> Optional[dict]:
        """URL'den HTML çek (curl_cffi ile - tarayıcı taklidi)"""
        for attempt in range(retries + 1):
            try:
                # curl_cffi kullanarak gerçek bir tarayıcı gibi davran
                # impersonate="chrome110" -> Bot korumasını aşar
                async with AsyncSession(impersonate="chrome110") as session:
                    response = await session.get(
                        url, 
                        timeout=30,
                        allow_redirects=True
                    )
                    
                    if response.status_code == 200:
                        html = response.text
                        final_url = str(response.url)
                        
                        # Log at
                        logger.info(f"✅ Link çekildi ({len(html)} bytes): {final_url}")
                        
                        # HTML'i çok kırpmayalım, Amazon'un yapısı karmaşık olabilir
                        # Ama yine de devasa dosyaları limitleyelim (1MB)
                        if len(html) > 1000000:
                            html = html[:1000000]
                            
                        return {'html': html, 'final_url': final_url}
                    else:
                        logger.warning(f"⚠️ HTTP {response.status_code} - {url}")
                            
            except Exception as e:
                logger.warning(f"⚠️ Link çekme denemesi {attempt + 1}/{retries + 1} başarısız: {e}")
                if attempt < retries:
                    await asyncio.sleep(1)
        
        return None

    def extract_image_from_html(self, html: str, base_url: str) -> Optional[str]:
        """HTML'den görsel URL'i çıkar"""
        soup = BeautifulSoup(html, 'html.parser')
        base_url_obj = urlparse(base_url)

        # 1. JSON-LD Schema
        json_ld_scripts = soup.find_all('script', type='application/ld+json')
        for script in json_ld_scripts:
            try:
                data = json.loads(script.string)
                image = self._find_image_in_json(data)
                if image and not image.startswith('blob:'):
                    return self._resolve_url(image, base_url_obj)
            except:
                pass

        # 2. Open Graph
        og_image = soup.find('meta', property='og:image')
        if og_image and og_image.get('content') and not og_image.get('content').startswith('blob:'):
            return self._resolve_url(og_image.get('content'), base_url_obj)

        # 3. Twitter Card
        twitter_image = soup.find('meta', attrs={'name': 'twitter:image'})
        if twitter_image and twitter_image.get('content') and not twitter_image.get('content').startswith('blob:'):
            return self._resolve_url(twitter_image.get('content'), base_url_obj)

        # 4. Trendyol özel
        if 'trendyol' in base_url_obj.hostname.lower():
            hb_image = soup.find(attrs={'data-image': True})
            if hb_image and hb_image.get('data-image'):
                return self._resolve_url(hb_image.get('data-image'), base_url_obj)

        # 5. Itemprop image
        itemprop_image = soup.find(attrs={'itemprop': 'image'})
        if itemprop_image:
            image_url = itemprop_image.get('content') or itemprop_image.get('src')
            if image_url and not image_url.startswith('blob:'):
                return self._resolve_url(image_url, base_url_obj)

        # 6. Product image class'ları
        product_img = soup.find('img', class_=re.compile(r'product|main|primary', re.I))
        if product_img and product_img.get('src'):
            src = product_img.get('src')
            if not src.startswith('blob:') and 'icon' not in src and 'logo' not in src:
                return self._resolve_url(src, base_url_obj)

        # 7. İlk büyük img tag
        for img in soup.find_all('img'):
            src = img.get('src') or img.get('data-src')
            if src and not src.startswith('blob:') and 'icon' not in src and 'logo' not in src:
                if src.startswith('http') or src.startswith('/'):
                    return self._resolve_url(src, base_url_obj)

        return None


    def extract_html_data(self, html: str, base_url: str) -> dict:
        """HTML'den fiyat ve diğer bilgileri çek - Geliştirilmiş versiyon"""
        data = {'price': 0.0, 'original_price': 0.0}
        if not html:
            return data

        try:
            soup = BeautifulSoup(html, 'lxml')
            parsed_url = urlparse(base_url)
            hostname = parsed_url.hostname.lower() if parsed_url.hostname else ''

            logger.info(f"🔍 HTML Analizi yapılıyor: {hostname}")

            # --- AMAZON ÖZEL MANTIK ---
            if 'amazon' in hostname:
                logger.info("🔍 Amazon detaylı fiyat analizi yapılıyor...")
                
                # 1. İndirimli Fiyatı (Price To Pay) Bul - ÖNCELİK: En güvenilir selector'lar
                # ÖNEMLİ: Amazon'da .priceToPay = İndirimli fiyat, .basisPrice = Eski fiyat
                price_selectors = [
                    ('#corePriceDisplay_desktop_feature_div .a-price.priceToPay .a-offscreen', 'Ana fiyat kutusu (gizli)'),
                    ('.priceToPay span.a-offscreen', 'PriceToPay gizli metin'),
                    ('#apex_desktop .a-price.priceToPay .a-offscreen', 'Apex fiyat kutusu'),
                    ('#corePrice_feature_div .a-price.priceToPay .a-offscreen', 'CorePrice fiyat kutusu'),
                    ('.priceToPay', 'PriceToPay görünür metin'),
                    ('#corePriceDisplay_desktop_feature_div .a-price-whole', 'Ana fiyat (tam kısım)'),
                    ('#apex_desktop .a-price-whole', 'Apex fiyat (tam kısım)'),
                ]
                
                # Önce tüm priceToPay elementlerini bul ve en küçük fiyatı al (indirimli fiyat genelde daha küçük)
                price_to_pay_elements = soup.select('.priceToPay')
                if price_to_pay_elements:
                    logger.info(f"🔍 {len(price_to_pay_elements)} adet .priceToPay elementi bulundu")
                    found_prices = []
                    for elem in price_to_pay_elements:
                        # Önce .a-offscreen içindeki gizli metni dene
                        hidden = elem.select_one('span.a-offscreen')
                        if hidden:
                            price_text = hidden.get_text(strip=True)
                        else:
                            price_text = elem.get_text(strip=True)
                        
                        price = self._parse_price(price_text)
                        if price >= 20:
                            found_prices.append(price)
                            logger.debug(f"   .priceToPay fiyat bulundu: {price} TL (metin: '{price_text}')")
                    
                    if found_prices:
                        # En küçük fiyatı al (indirimli fiyat)
                        data['price'] = min(found_prices)
                        logger.info(f"✅ Amazon İndirimli Fiyat Bulundu (.priceToPay): {data['price']} TL")
                
                # Eğer .priceToPay ile bulunamadıysa, diğer selector'ları dene
                if data['price'] == 0:
                    for selector, desc in price_selectors:
                        elem = soup.select_one(selector)
                        if elem:
                            price_text = elem.get_text(strip=True)
                            logger.debug(f"🔍 Selector '{desc}' bulundu: '{price_text}'")
                            price = self._parse_price(price_text)
                            logger.debug(f"   Parse sonucu: {price} TL")
                            if price >= 20:
                                data['price'] = price
                                logger.info(f"✅ Amazon İndirimli Fiyat Bulundu: {price} TL ({desc})")
                                break
                        else:
                            logger.debug(f"   Selector '{desc}' bulunamadı")
                
                # Eğer hala indirimli fiyat bulunamadıysa, log at
                if data['price'] == 0:
                    logger.warning("⚠️ Amazon indirimli fiyat bulunamadı! Tüm selector'lar denendi.")
                
                # 2. Orijinal Fiyatı (Basis Price / List Price) Bul
                # ÖNEMLİ: .basisPrice = Eski fiyat, .priceToPay = Yeni fiyat
                # Orijinal fiyat, indirimli fiyattan BÜYÜK olmalı
                
                # Önce tüm .basisPrice elementlerini bul
                basis_price_elements = soup.select('.basisPrice')
                if basis_price_elements:
                    logger.info(f"🔍 {len(basis_price_elements)} adet .basisPrice elementi bulundu")
                    found_original_prices = []
                    for elem in basis_price_elements:
                        # Önce .a-offscreen içindeki gizli metni dene
                        hidden = elem.select_one('span.a-offscreen')
                        if hidden:
                            price_text = hidden.get_text(strip=True)
                        else:
                            price_text = elem.get_text(strip=True)
                        
                        original = self._parse_price(price_text)
                        # Orijinal fiyat, indirimli fiyattan büyük olmalı
                        if original > data['price'] and original > 20:
                            found_original_prices.append(original)
                            logger.debug(f"   .basisPrice fiyat bulundu: {original} TL (metin: '{price_text}')")
                    
                    if found_original_prices:
                        # En büyük fiyatı al (orijinal fiyat)
                        data['original_price'] = max(found_original_prices)
                        logger.info(f"✅ Amazon Orijinal Fiyat Bulundu (.basisPrice): {data['original_price']} TL")

                # Eğer .basisPrice ile bulunamadıysa, diğer selector'ları dene
                if data['original_price'] == 0:
                    original_selectors = [
                        ('.basisPrice span.a-offscreen', 'BasisPrice gizli metin'),
                        ('.basisPrice', 'BasisPrice görünür metin'),
                        ('span.a-price.a-text-price span.a-offscreen', 'Üstü çizili fiyat (gizli)'),
                        ('span.a-price.a-text-price', 'Üstü çizili fiyat (görünür)'),
                        ('.a-text-strike', 'Strike text'),
                        ('span[data-a-strike="true"] span.a-offscreen', 'Strike data attribute'),
                    ]
                    
                    for selector, desc in original_selectors:
                        elem = soup.select_one(selector)
                        if elem:
                            price_text = elem.get_text(strip=True)
                            logger.debug(f"🔍 Orijinal fiyat selector '{desc}' bulundu: '{price_text}'")
                            original = self._parse_price(price_text)
                            logger.debug(f"   Parse sonucu: {original} TL")
                            # Orijinal fiyat, indirimli fiyattan büyük olmalı
                            if original > data['price'] and original > 20:
                                data['original_price'] = original
                                logger.info(f"✅ Amazon Orijinal Fiyat Bulundu: {original} TL ({desc})")
                                break
                
                # Sonuçları logla
                logger.info(f"📊 Amazon Fiyat Analizi Sonucu: İndirimli={data['price']} TL, Orijinal={data['original_price']} TL")
                
                return data

            # --- HEPSİBURADA ÖZEL MANTIK ---
            if 'hepsiburada' in hostname:
                logger.info("🔍 Hepsiburada fiyat analizi yapılıyor...")
                
                # Hepsiburada selector'ları
                price_selectors = [
                    ('div[data-bind="markupText:\'currentPrice\'"]', 'Ana fiyat kutusu'),
                    ('span[data-bind="markupText:\'currentPrice\'"]', 'Span fiyat'),
                    ('div.product-price span', 'Product price span'),
                    ('.price-value', 'Price value'),
                ]
                
                for selector, desc in price_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        logger.debug(f"🔍 Selector '{desc}' bulundu: '{price_text}'")
                        price = self._parse_price(price_text)
                        if price >= 10:
                            data['price'] = price
                            logger.info(f"✅ Hepsiburada Fiyat Bulundu: {price} TL ({desc})")
                            break
                
                # Eski fiyat için
                original_selectors = [
                    ('div[data-bind="markupText:\'oldPrice\'"]', 'Eski fiyat kutusu'),
                    ('.old-price', 'Old price'),
                    ('.strikethrough', 'Strikethrough price'),
                ]
                
                for selector, desc in original_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        original = self._parse_price(price_text)
                        if original > data['price'] and original > 10:
                            data['original_price'] = original
                            logger.info(f"✅ Hepsiburada Eski Fiyat: {original} TL ({desc})")
                            break
                
                if data['price'] > 0:
                    return data
            
            # --- TRENDYOL ÖZEL MANTIK ---
            if 'trendyol' in hostname:
                logger.info("🔍 Trendyol fiyat analizi yapılıyor...")
                
                price_selectors = [
                    ('span.prc-dsc', 'İndirimli fiyat'),
                    ('div.prc-box-dscntd', 'İndirim kutusu'),
                    ('span.prc-slg', 'Satış fiyatı'),
                    ('.product-price', 'Product price'),
                ]
                
                for selector, desc in price_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        price = self._parse_price(price_text)
                        if price >= 10:
                            data['price'] = price
                            logger.info(f"✅ Trendyol Fiyat: {price} TL ({desc})")
                            break
                
                # Eski fiyat
                original_selectors = [
                    ('span.prc-org', 'Orijinal fiyat'),
                    ('div.prc-box-orgnl', 'Orijinal kutu'),
                    ('.old-price', 'Old price'),
                ]
                
                for selector, desc in original_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        original = self._parse_price(price_text)
                        if original > data['price'] and original > 10:
                            data['original_price'] = original
                            logger.info(f"✅ Trendyol Eski Fiyat: {original} TL ({desc})")
                            break
                
                if data['price'] > 0:
                    return data
            
            # --- N11 ÖZEL MANTIK ---
            if 'n11.com' in hostname:
                logger.info("🔍 N11 fiyat analizi yapılıyor...")
                
                price_selectors = [
                    ('.newPrice ins', 'Yeni fiyat'),
                    ('.priceContainer ins', 'Fiyat container'),
                    ('.ins', 'Ins tag'),
                    ('.product-new-price', 'Product new price'),
                ]
                
                for selector, desc in price_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        price = self._parse_price(price_text)
                        if price >= 5:
                            data['price'] = price
                            logger.info(f"✅ N11 Fiyat: {price} TL ({desc})")
                            break
                
                # Eski fiyat
                original_selectors = [
                    ('.oldPrice del', 'Eski fiyat del'),
                    ('.product-old-price', 'Product old price'),
                ]
                
                for selector, desc in original_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        original = self._parse_price(price_text)
                        if original > data['price'] and original > 5:
                            data['original_price'] = original
                            logger.info(f"✅ N11 Eski Fiyat: {original} TL ({desc})")
                            break
                
                if data['price'] > 0:
                    return data
            
            # --- MİGROS & A101 & ŞOK ÖZEL MANTIK ---
            if any(x in hostname for x in ['migros', 'a101', 'sokmarket']):
                logger.info(f"🔍 {hostname} fiyat analizi yapılıyor...")
                
                price_selectors = [
                    ('.product-price', 'Product price'),
                    ('.price', 'Price'),
                    ('.amount', 'Amount'),
                    ('span[itemprop="price"]', 'Schema price'),
                    ('.current-price', 'Güncel fiyat'),
                ]
                
                for selector, desc in price_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        price = self._parse_price(price_text)
                        if price >= 5:
                            data['price'] = price
                            logger.info(f"✅ Market Fiyat: {price} TL ({desc})")
                            break
                
                if data['price'] > 0:
                    return data

            # --- GENEL MANTIK (Diğer Siteler) ---
            # 1. JSON-LD Schema (EN ÖNCELİKLİ)
        json_ld_scripts = soup.find_all('script', type='application/ld+json')
        for script in json_ld_scripts:
            try:
                    if not script.string: continue
                    js_data = json.loads(script.string)
                    
                    def find_price_recursive(obj):
                        if isinstance(obj, dict):
                            # Price field'ı
                            if 'price' in obj and (isinstance(obj['price'], (int, float, str))):
                                price = self._parse_price(str(obj['price']))
                                if price >= 10:
                                    return price
                            # Offers içinde price
                            if 'offers' in obj:
                                result = find_price_recursive(obj['offers'])
                                if result:
                                    return result
                            # lowPrice (en düşük fiyat)
                            if 'lowPrice' in obj:
                                price = self._parse_price(str(obj['lowPrice']))
                                if price >= 10:
                                    return price
                            # highPrice varsa eski fiyat olabilir
                            if 'highPrice' in obj and data['price'] > 0:
                                high = self._parse_price(str(obj['highPrice']))
                                if high > data['price']:
                                    data['original_price'] = high
                        elif isinstance(obj, list):
                            for item in obj:
                                res = find_price_recursive(item)
                                if res: return res
                        return None

                    price = find_price_recursive(js_data)
                if price and price >= 10:
                        data['price'] = price
                    logger.info(f"✅ Fiyat bulundu (JSON-LD): {price} TL")
                        return data
                except Exception as e:
                    logger.debug(f"JSON-LD parse hatası: {e}")
                    continue

            # 2. Meta tags
        meta_selectors = [
            {'property': 'product:price:amount'},
            {'property': 'og:price:amount'},
            {'name': 'price'},
            {'itemprop': 'price'},
            {'property': 'product:sale_price:amount'},
        ]
        for selector in meta_selectors:
            price_meta = soup.find('meta', selector)
            if price_meta and price_meta.get('content'):
                price = self._parse_price(price_meta.get('content'))
                if price >= 10:
                        data['price'] = price
                    logger.info(f"✅ Fiyat bulundu (Meta {selector}): {price} TL")
                        return data

            # 3. Genel HTML Selectors (Geniş Kapsam)
            general_selectors = [
                # Öncelikli
                'span[itemprop="price"]',
                'meta[itemprop="price"]',
                '.product-price',
                '.price',
                '.current-price',
                '.sale-price',
                '.amount',
                # Yaygın class isimleri
                '.price-value',
                '.product-price-value',
                '.selling-price',
                '.final-price',
                '.discounted-price',
                # Data attribute'ları
                '[data-price]',
                '[data-product-price]',
                # Genel
                'div[class*="price"]',
                'span[class*="price"]',
                'div[class*="Price"]',
                'span[class*="Price"]',
            ]
            
            for selector in general_selectors:
                elem = soup.select_one(selector)
                if elem:
                    # Data attribute kontrolü
                    if elem.has_attr('data-price'):
                        price_text = elem['data-price']
                    elif elem.has_attr('content'):
                        price_text = elem['content']
                    else:
                        price_text = elem.get_text(strip=True)
                    
                    price = self._parse_price(price_text)
                    if price >= 10:
                        data['price'] = price
                        logger.info(f"✅ Fiyat bulundu (HTML {selector}): {price} TL")
                        break

        except Exception as e:
            logger.error(f"HTML analiz hatası: {e}")
        
        return data


    async def analyze_deal_with_ai(self, text: str, link: str = "") -> Dict:
        """Gemini AI ile fırsat metnini analiz et"""
        if not model:
            logger.warning("⚠️ Gemini modeli yüklü değil, manuel analiz yapılacak.")
            return {}

        try:
            prompt = f"""
            Sen dünyanın en iyi e-ticaret veri analiz uzmanısın. Aşağıdaki Telegram mesajını ve linki analiz et.
            Bana SADECE geçerli bir JSON objesi döndür. Başka hiçbir metin yazma.
            
            Görevlerin:
            1. Ürün adını temizle (reklam, emoji, kanal adı, indirim oranları ve gereksiz kelimeleri at).
            2. Fiyatları bul (EN ÖNEMLİ GÖREV):
               - Güncel Fiyat (price): İndirimli, ödenecek son tutar.
               - Eski Fiyat (original_price): Üstü çizili, "önceki fiyat" veya piyasa fiyatı. (Yoksa 0 yaz).
               
               DİKKAT (Fiyat Kuralları):
               - "X TL x 3 ay" gibi taksit tutarlarını ASLA fiyat olarak alma.
               - Yüzdelik indirim oranlarını (örn: %57) fiyat sanma.
               - Eğer "Sepette X TL" veya "Kuponla X TL" diyorsa, o en düşük fiyatı 'price' olarak al.
               - Fiyatlar her zaman TL cinsinden bir sayı olmalıdır (örn: 1299.50).
               
            3. Mağazayı bul: Linkten veya metinden gerçek satıcıyı (Trendyol, Hepsiburada, Amazon, Pazarama, N11, Teknosa, MediaMarkt vb.) bul.
            4. Kategoriyi belirle. Aşağıdaki listeden EN UYGUN olanı seç (ZORUNLU):
               ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'kitap_hobi', 'yapi_oto', 'supermarket']
               
               ÖNEMLİ KATEGORİ KURALLARI:
               - 📱 'elektronik': Telefon, tablet, laptop, bilgisayar, TV, beyaz eşya, küçük ev aletleri (airfryer, vantilatör, kahve makinesi), kulaklık, akıllı saat, konsol, oyun, kamera, drone.
               - 👕 'moda': Kıyafet, ayakkabı, çanta, saat, gözlük, aksesuar, takı, bot, terlik, mont, kazak.
               - 🏠 'ev_yasam': Mobilya, ev tekstili (battaniye, çarşaf), mutfak gereçleri (tava, tencere), aydınlatma, dekorasyon, kırtasiye.
               - 👶 'anne_bebek': Bebek bezi, mama, biberon, emzik, bebek arabası, oto koltuğu, bebek/çocuk oyuncakları (Lego, Barbie vb.).
               - 💄 'kozmetik': Krem, şampuan, parfüm, makyaj, tıraş, epilasyon, diş bakımı, cilt bakımı, saç bakımı.
               - ⛺ 'spor_outdoor': Kamp malzemesi, spor aleti, bisiklet, fitness ekipmanları, yoga matı, dambıl, termos.
               - 📚 'kitap_hobi': Kitap, roman, dergi, müzik enstrümanları, sanat malzemeleri, puzzle, kutu oyunu.
               - 🚗 'yapi_oto': Oto lastik, motor yağı, araç aksesuarları, matkap, tornavida, elektrik malzemeleri, bahçe aletleri, banyo/tesisat.
               - 🛒 'supermarket': Gıda, deterjan, temizlik ürünleri, kağıt ürünleri, yiyecek, içecek, kedi/köpek maması, kedi kumu.
            
            Girdi Metni:
            {text}
            
            Girdi Linki:
            {link}
            
            İstenen JSON Formatı:
            {{
                "title": "Ürün Adı",
                "price": 1234.50,
                "original_price": 1500.00,
                "store": "Mağaza Adı",
                "category": "kategori_kodu",
                "confidence": "high"
            }}
            """

            # Daha yaratıcı olmayan, kesin sonuçlar için temperature'ı düşük tutalım
            response = await model.generate_content_async(
                prompt,
                generation_config=genai.types.GenerationConfig(
                    temperature=0.1,
                    max_output_tokens=500,
                )
            )
            
            json_text = response.text.replace('```json', '').replace('```', '').strip()
            data = json.loads(json_text)
            
            # Veri tiplerini doğrula
            if 'price' in data:
                try: data['price'] = float(data['price'])
                except: data['price'] = 0.0
            if 'original_price' in data:
                try: data['original_price'] = float(data['original_price'])
                except: data['original_price'] = 0.0
                
            logger.info(f"🧠 AI Gelişmiş Analiz Sonucu: {data}")
            return data

        except Exception as e:
            logger.error(f"❌ AI Analiz Hatası: {e}")
            return {}

        except Exception as e:
            logger.error(f"❌ AI Analiz Hatası: {e}")
            return {}

    def extract_category_from_html(self, html: str, base_url: str, title: str = '') -> Optional[str]:
        """HTML'den kategori çıkar"""
        soup = BeautifulSoup(html, 'html.parser')
        base_url_obj = urlparse(base_url)
        hostname = base_url_obj.hostname.lower() if base_url_obj.hostname else ''
        url_path = base_url_obj.path.lower()

        logger.info(f"🏷️ Kategori aranıyor: {hostname}")

        # 1. JSON-LD Schema'dan kategori çıkar
        json_ld_scripts = soup.find_all('script', type='application/ld+json')
        for script in json_ld_scripts:
            try:
                data = json.loads(script.string)
                category = self._find_category_in_json(data)
                if category:
                    logger.info(f"✅ Kategori bulundu (JSON-LD): {category}")
                    return category
            except Exception as e:
                logger.debug(f"JSON-LD parse hatası: {e}")

        # 2. Meta tag'lerden kategori çıkar
        meta_selectors = [
            {'property': 'product:category'},
            {'property': 'og:type'},
            {'name': 'category'},
            {'itemprop': 'category'},
        ]
        for selector in meta_selectors:
            meta = soup.find('meta', selector)
            if meta and meta.get('content'):
                category = self._map_category_keyword(meta.get('content'), title)
                if category:
                    logger.info(f"✅ Kategori bulundu (Meta {selector}): {category}")
                    return category

        # 3. Breadcrumb'lardan kategori çıkar
        breadcrumb_selectors = [
            '.breadcrumb a',
            '.breadcrumbs a',
            '[itemtype*="BreadcrumbList"] a',
            'nav[aria-label*="breadcrumb"] a',
        ]
        for selector in breadcrumb_selectors:
            breadcrumbs = soup.select(selector)
            if breadcrumbs:
                for breadcrumb in breadcrumbs[-3:]:  # Son 3 breadcrumb'a bak
                    text = breadcrumb.get_text().strip().lower()
                    category = self._map_category_keyword(text, title)
                    if category:
                        logger.info(f"✅ Kategori bulundu (Breadcrumb): {category}")
                        return category

        # 4. URL path'inden kategori çıkar
        if url_path:
            category = self._extract_category_from_path(url_path, title)
            if category:
                logger.info(f"✅ Kategori bulundu (URL path): {category}")
                return category

        # 5. Site-özel kategori yolları
        category = self._extract_site_specific_category(hostname, url_path, title)
        if category:
            logger.info(f"✅ Kategori bulundu (Site-özel): {category}")
            return category

        logger.warning("⚠️ HTML'de kategori bulunamadı")
        return None

    def _find_category_in_json(self, obj) -> Optional[str]:
        """JSON objesinde kategori ara"""
        if isinstance(obj, dict):
            # category field'ı kontrol et
            if 'category' in obj:
                cat = obj['category']
                if isinstance(cat, str):
                    return self._map_category_keyword(cat)
                elif isinstance(cat, list) and len(cat) > 0:
                    return self._map_category_keyword(cat[0])
            # Recursive search
            for key, value in obj.items():
                result = self._find_category_in_json(value)
                if result:
                    return result
        elif isinstance(obj, list):
            for item in obj:
                result = self._find_category_in_json(item)
                if result:
                    return result
        return None

    def _extract_category_from_path(self, path: str, title: str = '') -> Optional[str]:
        """URL path'inden kategori çıkar"""
        path_lower = path.lower()
        
        # Kategori anahtar kelimeleri - Flutter kategorilerine uygun
        category_keywords = {
            'elektronik': [
                'elektronik', 'bilgisayar', 'computer', 'pc', 'laptop', 'notebook', 'tablet', 'ipad',
                'telefon', 'phone', 'smartphone', 'iphone', 'android', 'samsung', 'xiaomi',
                'ekran-karti', 'gpu', 'islemci', 'cpu', 'anakart', 'motherboard', 'ram', 'ssd', 'hdd',
                'monitor', 'monitör', 'klavye', 'keyboard', 'mouse', 'fare', 'kulaklik', 'airpods',
                'televizyon', 'tv', 'akilli-saat', 'smartwatch', 'powerbank', 'sarj', 'charger',
                'beyaz-esya', 'buzdolabi', 'camasir-makinesi', 'bulasik-makinesi',
                'robot-supurge', 'vacuum', 'kahve-makinesi', 'mikser', 'blender',
                'kamera', 'camera', 'drone', 'gopro', 'fotograf',
                'konsol', 'playstation', 'xbox', 'nintendo', 'switch', 'oyun', 'game',
            ],
            'moda': [
                'giyim', 'moda', 'fashion', 'kiyafet', 'elbise', 'pantolon', 'gomlek',
                'tisort', 't-shirt', 'kazak', 'mont', 'ceket', 'ayakkabi', 'shoe',
                'bot', 'terlik', 'sandalet', 'topuklu', 'canta', 'bag', 'saat', 'watch',
                'gozluk', 'sunglasses', 'aksesuar', 'taki', 'jewelry', 'nike', 'adidas',
                'sort', 'etek', 'bluz', 'sweatshirt', 'hoodie', 'kemer', 'belt',
            ],
            'ev_yasam': [
                'mobilya', 'furniture', 'kanepe', 'sofa', 'koltuk', 'masa', 'table',
                'sandalye', 'chair', 'yatak', 'bed', 'dolap', 'wardrobe', 'sehpa',
                'ev-tekstili', 'carsaf', 'sheet', 'yorgan', 'battaniye', 'yastik',
                'perde', 'curtain', 'hali', 'carpet', 'havlu', 'towel',
                'mutfak', 'tava', 'pan', 'tencere', 'pot', 'bicak', 'knife',
                'tabak', 'plate', 'bardak', 'glass', 'fincan', 'cup',
                'aydinlatma', 'lighting', 'lamba', 'lamp', 'avize', 'led',
                'dekorasyon', 'decoration', 'vazo', 'vase', 'tablo', 'painting',
                'kirtasiye', 'stationery', 'kalem', 'pen', 'defter', 'notebook',
            ],
            'anne_bebek': [
                'bebek', 'baby', 'anne', 'cocuk', 'child', 'bebek-bezi', 'diaper',
                'mama', 'biberon', 'bottle', 'emzik', 'pacifier', 'bebek-arabasi',
                'stroller', 'oto-koltugu', 'car-seat', 'oyuncak', 'toy', 'lego',
                'barbie', 'hot-wheels', 'prima', 'sleepy', 'molfix', 'islak-mendil',
            ],
            'kozmetik': [
                'kozmetik', 'cosmetic', 'bakim', 'care', 'makyaj', 'makeup', 'parfum',
                'perfume', 'ruj', 'lipstick', 'krem', 'cream', 'sampuan', 'shampoo',
                'sac-kremi', 'conditioner', 'tiras', 'shave', 'jilet', 'razor',
                'epilasyon', 'fon', 'dryer', 'duzlestirici', 'straightener',
                'dis-fircasi', 'toothbrush', 'dis-macunu', 'toothpaste',
                'gratis', 'watsons', 'rossmann', 'deodorant', 'roll-on',
            ],
            'spor_outdoor': [
                'spor', 'sport', 'fitness', 'kosu', 'running', 'yoga', 'pilates',
                'kamp', 'camping', 'cadir', 'tent', 'uyku-tulumu', 'sleeping-bag',
                'termos', 'thermos', 'matara', 'flask', 'bisiklet', 'bicycle',
                'scooter', 'kaykay', 'skateboard', 'top', 'ball', 'forma', 'jersey',
                'decathlon', 'dambil', 'dumbbell', 'halter', 'barbell',
                'kosu-bandi', 'treadmill', 'yoga-mati', 'yoga-mat',
            ],
            'kitap_hobi': [
                'kitap', 'book', 'roman', 'novel', 'dergi', 'magazine', 'hobi',
                'hobby', 'puzzle', 'yapboz', 'kutu-oyunu', 'board-game',
                'muzik', 'music', 'enstruman', 'instrument', 'gitar', 'guitar',
                'piyano', 'piano', 'sanat', 'art', 'boya', 'paint', 'firca', 'brush',
            ],
            'yapi_oto': [
                'oto', 'auto', 'araba', 'car', 'arac', 'vehicle', 'lastik', 'tire',
                'silecek', 'wiper', 'motor-yagi', 'oil', 'aku', 'battery',
                'yapi-market', 'hardware', 'hiradavat', 'matkap', 'drill',
                'tornavida', 'screwdriver', 'testere', 'saw', 'cekic', 'hammer',
                'ampul', 'bulb', 'elektrik', 'electric', 'kablo', 'cable',
                'bahce', 'garden', 'bahce-hortumu', 'hose', 'cim-bicme', 'mower',
                'mangal', 'grill', 'koctas', 'bauhaus', 'praktiker',
                'banyo', 'bathroom', 'musluk', 'faucet', 'dus', 'shower', 'lavabo',
            ],
            'supermarket': [
                'market', 'supermarket', 'gida', 'food', 'yiyecek', 'icecek',
                'kahve', 'coffee', 'cay', 'tea', 'yag', 'oil', 'zeytinyagi',
                'un', 'flour', 'seker', 'sugar', 'tuz', 'salt', 'baharat', 'spice',
                'makarna', 'pasta', 'pirinc', 'rice', 'bulgur', 'salca', 'paste',
                'deterjan', 'detergent', 'temizlik', 'cleaning', 'kagit-havlu',
                'tuvalet-kagidi', 'toilet-paper', 'sabun', 'soap', 'cop-poseti',
                'migros', 'carrefour', 'a101', 'bim', 'sok', 'getir', 'yemeksepeti',
                'cikolata', 'chocolate', 'biskuvi', 'biscuit', 'cips', 'chips',
                'kedi-mamasi', 'cat-food', 'kopek-mamasi', 'dog-food', 'kedi-kumu',
            ],
        }
        
        for category_id, keywords in category_keywords.items():
            for keyword in keywords:
                if keyword in path_lower:
                    return category_id
        
        return None

    def _extract_site_specific_category(self, hostname: str, path: str, title: str = '') -> Optional[str]:
        """Site-özel kategori çıkarma"""
        path_lower = path.lower()
        
        # Trendyol
        if 'trendyol' in hostname:
            # Trendyol kategori yapısı: /c/{category}
            if '/c/' in path_lower:
                parts = path_lower.split('/c/')
                if len(parts) > 1:
                    category_part = parts[1].split('/')[0]
                    return self._map_category_keyword(category_part, title)
        
        # Hepsiburada
        if 'hepsiburada' in hostname:
            # Hepsiburada kategori yapısı: /{category}/...
            if path_lower.count('/') >= 2:
                parts = [p for p in path_lower.split('/') if p]
                if len(parts) >= 1:
                    category_part = parts[0]
                    return self._map_category_keyword(category_part, title)
        
        # N11
        if 'n11.com' in hostname:
            # N11 kategori yapısı: /{category}/...
            if path_lower.count('/') >= 2:
                parts = [p for p in path_lower.split('/') if p]
                if len(parts) >= 1:
                    category_part = parts[0]
                    return self._map_category_keyword(category_part, title)
        
        return None

    def extract_category_from_url(self, url: str, title: str = '') -> Optional[str]:
        """URL'den kategori çıkar"""
        try:
            parsed = urlparse(url)
            path = parsed.path.lower()
            return self._extract_category_from_path(path, title)
        except:
            return None

    def extract_category_from_title(self, title: str) -> Optional[str]:
        """Başlıktan kategori çıkar"""
        if not title:
            return None
        
        title_lower = title.lower()
        
        # Kategori anahtar kelimeleri
        category_keywords = {
            # Bilgisayar
            'bilgisayar': ['bilgisayar', 'computer', 'pc', 'laptop', 'notebook', 'ekran kartı', 'gpu', 'işlemci', 'cpu', 'anakart', 'motherboard', 'ram', 'ssd', 'hdd', 'depolama', 'storage', 'güç kaynağı', 'psu', 'power supply', 'kasa', 'monitör', 'monitor', 'klavye', 'keyboard', 'mouse', 'fare', 'webcam', 'yazıcı', 'printer'],
            
            # Mobil Cihazlar
            'mobil_cihazlar': ['telefon', 'phone', 'smartphone', 'iphone', 'android', 'samsung', 'xiaomi', 'huawei', 'tablet', 'ipad', 'akıllı saat', 'smartwatch', 'bileklik', 'powerbank', 'şarj', 'charger', 'kılıf', 'case', 'kulaklık', 'headphone', 'earphone', 'airpods', 'bluetooth'],
            
            # Konsol ve Oyun
            'konsol_oyun': ['konsol', 'console', 'playstation', 'ps4', 'ps5', 'xbox', 'nintendo', 'switch', 'oyun', 'game', 'gamepad', 'joystick', 'direksiyon', 'steering', 'controller', 'steam', 'epic games', 'game pass', 'ps plus'],
            
            # Ev Elektroniği
            'ev_elektronigi_yasam': ['televizyon', 'tv', 'akıllı ev', 'smart home', 'robot süpürge', 'süpürge', 'vacuum', 'aydınlatma', 'lighting', 'kişisel bakım', 'personal care', 'tıraş', 'shave', 'hobi', 'hobby', 'drone', 'kamera', 'camera', 'fotoğraf', 'photo', 'ütü', 'klima', 'vantilatör', 'airfryer', 'fritöz', 'kahve makinesi', 'çay makinesi', 'blender', 'beyaz eşya', 'buzdolabı', 'çamaşır makinesi'],
            
            # Giyim ve Moda
            'giyim_moda': ['giyim', 'moda', 'kıyafet', 'elbise', 'pantolon', 'gömlek', 'tişört', 't-shirt', 'kazak', 'mont', 'ceket', 'ayakkabı', 'bot', 'terlik', 'çanta', 'saat', 'gözlük', 'aksesuar', 'takı', 'nike', 'adidas', 'puma', 'skechers', 'zara'],
            
            # Süpermarket
            'supermarket': ['market', 'gıda', 'yiyecek', 'içecek', 'kahve', 'çay', 'yağ', 'un', 'şeker', 'deterjan', 'temizlik', 'kağıt havlu', 'tuvalet kağıdı', 'şampuan', 'diş macunu', 'sabun', 'migros', 'carrefour', 'a101', 'bim', 'şok', 'getir', 'yemeksepeti', 'omo', 'ariel', 'persil', 'fairy', 'yumoş'],
            
            # Kozmetik
            'kozmetik_bakim': ['kozmetik', 'bakım', 'makyaj', 'parfüm', 'ruj', 'krem', 'cilt bakımı', 'saç bakımı', 'tıraş', 'jilet', 'epilasyon', 'fön', 'düzleştirici', 'gratis', 'watsons'],
            
            # Oto & Yapı
            'oto_yapi_market': ['oto', 'araba', 'araç', 'lastik', 'silecek', 'motor yağı', 'yapı market', 'matkap', 'tornavida', 'boya', 'ampul', 'bahçe', 'mangal', 'koçtaş', 'bauhaus'],
            
            # Anne & Bebek
            'anne_bebek': ['bebek', 'anne', 'çocuk', 'bebek bezi', 'mama', 'biberon', 'emzik', 'bebek arabası', 'oto koltuğu', 'oyuncak', 'lego', 'barbie', 'hot wheels', 'prima', 'sleepy'],
            
            # Spor & Outdoor
            'spor_outdoor': ['spor', 'kamp', 'çadır', 'uyku tulumu', 'termos', 'matara', 'bisiklet', 'scooter', 'kaykay', 'top', 'forma', 'decathlon'],
            
            # Kitap & Hobi
            'kitap_hobi': ['kitap', 'roman', 'dergi', 'hobi', 'puzzle', 'kutu oyunu', 'kırtasiye', 'kalem', 'defter', 'okul'],
            
            # Ağ & Yazılım
            'ag_yazilim': ['modem', 'router', 'mesh', 'ağ', 'network', 'yazılım', 'software', 'işletim sistemi', 'os', 'antivirus', 'antivirüs', 'vpn', 'lisans', 'windows', 'office'],
        }
        
        for category_id, keywords in category_keywords.items():
            for keyword in keywords:
                if keyword in title_lower:
                    return category_id
        
        return None

    def _map_category_keyword(self, keyword: str, title: str = '') -> Optional[str]:
        """Anahtar kelimeyi kategori ID'sine çevir - İyileştirilmiş eşleşme"""
        if not keyword:
            return None
        
        keyword_lower = keyword.lower().strip()
        title_lower = title.lower() if title else ''
        combined = f"{keyword_lower} {title_lower}"
        
        # Kategori mapping - Flutter kategorileriyle senkronize (EN ÖNEMLİ)
        category_mapping = {
            # 1. ELEKTRONİK (Ana Kategori - Flutter: 'elektronik')
            'bilgisayar': 'elektronik', 'computer': 'elektronik', 'pc': 'elektronik', 'laptop': 'elektronik',
            'notebook': 'elektronik', 'ekran kartı': 'elektronik', 'gpu': 'elektronik', 'işlemci': 'elektronik', 
            'cpu': 'elektronik', 'anakart': 'elektronik', 'ram': 'elektronik', 'ssd': 'elektronik', 'hdd': 'elektronik',
            'depolama': 'elektronik', 'monitör': 'elektronik', 'monitor': 'elektronik', 'klavye': 'elektronik', 
            'keyboard': 'elektronik', 'mouse': 'elektronik', 'webcam': 'elektronik', 'yazıcı': 'elektronik', 'printer': 'elektronik',
            'power supply': 'elektronik', 'psu': 'elektronik', 
            # Telefon ve Tablet
            'telefon': 'elektronik', 'phone': 'elektronik', 'smartphone': 'elektronik', 'iphone': 'elektronik',
            'android': 'elektronik', 'samsung': 'elektronik', 'xiaomi': 'elektronik', 'tablet': 'elektronik', 
            'ipad': 'elektronik', 'akıllı saat': 'elektronik', 'smartwatch': 'elektronik', 'bileklik': 'elektronik', 
            'powerbank': 'elektronik', 'şarj': 'elektronik', 'kılıf': 'elektronik', 'kulaklık': 'elektronik', 
            'airpods': 'elektronik', 'bluetooth kulaklık': 'elektronik', 'earbuds': 'elektronik',
            # TV ve Ses
            'televizyon': 'elektronik', 'tv': 'elektronik', 'ses sistemi': 'elektronik', 'soundbar': 'elektronik', 'hoparlör': 'elektronik',
            # Beyaz Eşya
            'beyaz eşya': 'elektronik', 'buzdolabı': 'elektronik', 'çamaşır makinesi': 'elektronik', 'bulaşık makinesi': 'elektronik',
            'fırın': 'elektronik', 'mikrodalga': 'elektronik', 'klima': 'elektronik', 
            # Küçük Ev Aletleri
            'robot süpürge': 'elektronik', 'süpürge': 'elektronik', 'ütü': 'elektronik', 
            'vantilatör': 'elektronik', 'airfryer': 'elektronik', 'fritöz': 'elektronik', 
            'kahve makinesi': 'elektronik', 'çay makinesi': 'elektronik', 'blender': 'elektronik', 'mikser': 'elektronik',
            'tost makinesi': 'elektronik', 'su ısıtıcı': 'elektronik', 'kettle': 'elektronik', 'saç kurutma': 'elektronik',
            # Kamera ve Drone
            'kamera': 'elektronik', 'camera': 'elektronik', 'fotoğraf makinesi': 'elektronik', 'drone': 'elektronik', 'gopro': 'elektronik',
            # Konsol ve Oyun
            'konsol': 'elektronik', 'playstation': 'elektronik', 'ps4': 'elektronik', 'ps5': 'elektronik', 'xbox': 'elektronik', 
            'nintendo': 'elektronik', 'switch': 'elektronik', 'gamepad': 'elektronik', 'oyun': 'elektronik', 
            'steam': 'elektronik', 'epic games': 'elektronik', 'game pass': 'elektronik', 'ps plus': 'elektronik',
            
            # 2. MODA (Flutter: 'moda')
            'giyim': 'moda', 'moda': 'moda', 'kıyafet': 'moda', 'elbise': 'moda', 
            'pantolon': 'moda', 'gömlek': 'moda', 'tişört': 'moda', 't-shirt': 'moda', 'tisort': 'moda',
            'kazak': 'moda', 'mont': 'moda', 'ceket': 'moda', 'ayakkabı': 'moda', 'spor ayakkabı': 'moda',
            'bot': 'moda', 'terlik': 'moda', 'sandalet': 'moda', 'topuklu': 'moda',
            'çanta': 'moda', 'saat': 'moda', 'kol saati': 'moda', 'apple watch': 'moda',
            'gözlük': 'moda', 'güneş gözlüğü': 'moda', 'aksesuar': 'moda', 'takı': 'moda', 'kolye': 'moda',
            'nike': 'moda', 'adidas': 'moda', 'puma': 'moda', 'skechers': 'moda', 'zara': 'moda',
            'şort': 'moda', 'etek': 'moda', 'bluz': 'moda', 'sweatshirt': 'moda', 'hoodie': 'moda',
            
            # 3. EV & YAŞAM (Flutter: 'ev_yasam')
            'mobilya': 'ev_yasam', 'kanepe': 'ev_yasam', 'koltuk': 'ev_yasam', 'masa': 'ev_yasam', 'sandalye': 'ev_yasam',
            'yatak': 'ev_yasam', 'dolap': 'ev_yasam', 'sehpa': 'ev_yasam', 'raf': 'ev_yasam',
            'ev tekstili': 'ev_yasam', 'çarşaf': 'ev_yasam', 'yorgan': 'ev_yasam', 'battaniye': 'ev_yasam', 
            'yastık': 'ev_yasam', 'perde': 'ev_yasam', 'halı': 'ev_yasam', 'havlu': 'ev_yasam',
            'mutfak': 'ev_yasam', 'tava': 'ev_yasam', 'tencere': 'ev_yasam', 'bıçak': 'ev_yasam', 'tabak': 'ev_yasam',
            'bardak': 'ev_yasam', 'fincan': 'ev_yasam', 'çatal': 'ev_yasam', 'kaşık': 'ev_yasam',
            'aydınlatma': 'ev_yasam', 'lamba': 'ev_yasam', 'avize': 'ev_yasam', 'led': 'ev_yasam',
            'dekorasyon': 'ev_yasam', 'vazo': 'ev_yasam', 'tablo': 'ev_yasam', 'mum': 'ev_yasam', 'ayna': 'ev_yasam',
            'kırtasiye': 'ev_yasam', 'kalem': 'ev_yasam', 'defter': 'ev_yasam', 'ajanda': 'ev_yasam',
            'deterjan': 'ev_yasam', # Deterjan bazen ev yaşamda da aranır
            
            # 4. ANNE & BEBEK (Flutter: 'anne_bebek')
            'bebek': 'anne_bebek', 'anne': 'anne_bebek', 'çocuk': 'anne_bebek', 'bebek bezi': 'anne_bebek', 
            'mama': 'anne_bebek', 'biberon': 'anne_bebek', 'emzik': 'anne_bebek', 'bebek arabası': 'anne_bebek', 
            'oto koltuğu': 'anne_bebek', 'oyuncak': 'anne_bebek', 'lego': 'anne_bebek', 'barbie': 'anne_bebek', 
            'hot wheels': 'anne_bebek', 'prima': 'anne_bebek', 'sleepy': 'anne_bebek', 'molfix': 'anne_bebek',
            'islak mendil': 'anne_bebek', 'bebek banyosu': 'anne_bebek', 'bebek şampuanı': 'anne_bebek',
            
            # 5. KOZMETİK (Flutter: 'kozmetik')
            'kozmetik': 'kozmetik', 'bakım': 'kozmetik', 'makyaj': 'kozmetik', 'parfüm': 'kozmetik', 
            'ruj': 'kozmetik', 'krem': 'kozmetik', 'nemlendirici': 'kozmetik', 'güneş kremi': 'kozmetik',
            'cilt bakımı': 'kozmetik', 'saç bakımı': 'kozmetik', 'şampuan': 'kozmetik', 'saç kremi': 'kozmetik',
            'tıraş': 'kozmetik', 'jilet': 'kozmetik', 'epilasyon': 'kozmetik', 'fön': 'kozmetik', 
            'düzleştirici': 'kozmetik', 'saç maşası': 'kozmetik', 'diş fırçası': 'kozmetik', 'diş macunu': 'kozmetik',
            'gratis': 'kozmetik', 'watsons': 'kozmetik', 'rossmann': 'kozmetik',
            'deodorant': 'kozmetik', 'roll-on': 'kozmetik', 'fondöten': 'kozmetik', 'maskara': 'kozmetik',
            
            # 6. SPOR & OUTDOOR (Flutter: 'spor_outdoor')
            'spor': 'spor_outdoor', 'fitness': 'spor_outdoor', 'koşu': 'spor_outdoor', 'yoga': 'spor_outdoor',
            'kamp': 'spor_outdoor', 'çadır': 'spor_outdoor', 'uyku tulumu': 'spor_outdoor', 
            'termos': 'spor_outdoor', 'matara': 'spor_outdoor', 'bisiklet': 'spor_outdoor', 'scooter': 'spor_outdoor', 
            'kaykay': 'spor_outdoor', 'top': 'spor_outdoor', 'forma': 'spor_outdoor', 'decathlon': 'spor_outdoor',
            'dambıl': 'spor_outdoor', 'halter': 'spor_outdoor', 'koşu bandı': 'spor_outdoor', 'direnç bandı': 'spor_outdoor',
            'yoga matı': 'spor_outdoor', 'spor çantası': 'spor_outdoor', 'spor çorabı': 'spor_outdoor',
            
            # 7. KİTAP & HOBİ (Flutter: 'kitap_hobi')
            'kitap': 'kitap_hobi', 'roman': 'kitap_hobi', 'dergi': 'kitap_hobi', 'hobi': 'kitap_hobi', 
            'puzzle': 'kitap_hobi', 'yapboz': 'kitap_hobi', 'kutu oyunu': 'kitap_hobi', 
            'müzik': 'kitap_hobi', 'enstrüman': 'kitap_hobi', 'gitar': 'kitap_hobi', 'piyano': 'kitap_hobi',
            'sanat malzemesi': 'kitap_hobi', 'boya': 'kitap_hobi', 'fırça': 'kitap_hobi', 'tuval': 'kitap_hobi',
            
            # 8. YAPI & OTO (Flutter: 'yapi_oto')
            'oto': 'yapi_oto', 'araba': 'yapi_oto', 'araç': 'yapi_oto', 'lastik': 'yapi_oto', 
            'silecek': 'yapi_oto', 'motor yağı': 'yapi_oto', 'akü': 'yapi_oto', 'fren balata': 'yapi_oto',
            'yapı market': 'yapi_oto', 'yapı': 'yapi_oto', 'hırdavat': 'yapi_oto',
            'matkap': 'yapi_oto', 'tornavida': 'yapi_oto', 'testere': 'yapi_oto', 'çekiç': 'yapi_oto',
            'ampul': 'yapi_oto', 'elektrik': 'yapi_oto', 'kablo': 'yapi_oto', 'priz': 'yapi_oto',
            'bahçe': 'yapi_oto', 'bahçe hortumu': 'yapi_oto', 'çim biçme': 'yapi_oto', 'mangal': 'yapi_oto',
            'koçtaş': 'yapi_oto', 'bauhaus': 'yapi_oto', 'praktiker': 'yapi_oto',
            'banyo': 'yapi_oto', 'musluk': 'yapi_oto', 'duş': 'yapi_oto', 'lavabo': 'yapi_oto',
            
            # 9. SÜPERMARKET (Flutter: 'supermarket')
            'market': 'supermarket', 'gıda': 'supermarket', 'yiyecek': 'supermarket', 'içecek': 'supermarket', 
            'kahve': 'supermarket', 'çay': 'supermarket', 'yağ': 'supermarket', 'zeytinyağı': 'supermarket',
            'un': 'supermarket', 'şeker': 'supermarket', 'tuz': 'supermarket', 'baharat': 'supermarket',
            'makarna': 'supermarket', 'pirinç': 'supermarket', 'bulgur': 'supermarket', 'salça': 'supermarket',
            'süt': 'supermarket', 'yoğurt': 'supermarket', 'peynir': 'supermarket', 'tereyağı': 'supermarket',
            'deterjan': 'supermarket', 'çamaşır deterjanı': 'supermarket', 'bulaşık deterjanı': 'supermarket',
            'temizlik': 'supermarket', 'kağıt havlu': 'supermarket', 'tuvalet kağıdı': 'supermarket', 
            'sabun': 'supermarket', 'çöp poşeti': 'supermarket',
            'migros': 'supermarket', 'carrefour': 'supermarket', 'a101': 'supermarket', 'bim': 'supermarket', 
            'şok': 'supermarket', 'getir': 'supermarket', 'yemeksepeti': 'supermarket', 
            'omo': 'supermarket', 'ariel': 'supermarket', 'persil': 'supermarket', 'fairy': 'supermarket', 
            'yumoş': 'supermarket', 'finish': 'supermarket', 'domestos': 'supermarket',
            'çikolata': 'supermarket', 'bisküvi': 'supermarket', 'cips': 'supermarket', 'kola': 'supermarket',
            'kedi maması': 'supermarket', 'köpek maması': 'supermarket', 'kedi kumu': 'supermarket',
        }
        
        # Direkt eşleşme
        if keyword_lower in category_mapping:
            return category_mapping[keyword_lower]
        
        # Kısmi eşleşme (anahtar kelime içeriyorsa)
        # Önce uzun anahtar kelimeleri kontrol et (örn: "bebek bezi" > "bebek")
        sorted_keys = sorted(category_mapping.keys(), key=len, reverse=True)
        
        for key in sorted_keys:
            category_id = category_mapping[key]
            # Tam kelime eşleşmesi veya sınır kontrolü ile eşleşme
            pattern = r'(^|\s|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])' + re.escape(key) + r'($|\s|[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ])'
            if re.search(pattern, keyword_lower) or re.search(pattern, combined):
                return category_id
        
        return None

    def _find_image_in_json(self, obj) -> Optional[str]:
        """JSON objesinde görsel ara"""
        if isinstance(obj, dict):
            if 'image' in obj:
                img = obj['image']
                if isinstance(img, str):
                    return img
                elif isinstance(img, dict) and 'url' in img:
                    return img['url']
                elif isinstance(img, list) and len(img) > 0:
                    return img[0] if isinstance(img[0], str) else img[0].get('url')
            for key, value in obj.items():
                result = self._find_image_in_json(value)
                if result:
                    return result
        elif isinstance(obj, list):
            for item in obj:
                result = self._find_image_in_json(item)
                if result:
                    return result
        return None

    def _find_price_in_json(self, obj) -> Optional[float]:
        """JSON objesinde fiyat ara"""
        if isinstance(obj, dict):
            if 'price' in obj:
                return self._parse_price(obj['price'])
            if 'offers' in obj:
                offers = obj['offers']
                if isinstance(offers, dict) and 'price' in offers:
                    return self._parse_price(offers['price'])
            for key, value in obj.items():
                result = self._find_price_in_json(value)
                if result:
                    return result
        elif isinstance(obj, list):
            for item in obj:
                result = self._find_price_in_json(item)
                if result:
                    return result
        return None

    def _parse_price(self, price_str) -> float:
        """Fiyat string'ini parse et - İyileştirilmiş Türk formatı desteği"""
        if not price_str:
            return 0.0
        
        # Yüzdelik indirim oranlarını engelle (%57 gibi)
        if '%' in str(price_str):
            return 0.0
        
        # String'e çevir ve temizle
        price_str = str(price_str).strip()
        
        # Sadece sayı ve virgül/nokta kalsın
        # Önce para birimlerini temizle
        price_str = re.sub(r'(?:₺|TL|lira|TRY|USD|EUR|\$|€)', '', price_str, flags=re.I).strip()
        
        # Parantez içindeki (birim fiyat vb.) verileri temizle
        price_str = re.sub(r'\(.*?\)', '', price_str).strip()
        
        # Tüm harfleri temizle (sadece rakam ve noktalama kalsın)
        price_str = re.sub(r'[a-zA-Z]', '', price_str).strip()
        
        price_str = re.sub(r'[^\d.,]', '', price_str)
        
        if not price_str:
            return 0.0
            
        # ... (Geri kalan mantık aynı kalsın) ...
        price_str = re.sub(r'(?:₺|TL|lira|TRY)', '', price_str, flags=re.I).strip()
        price_str = re.sub(r'[^\d.,\s]', '', price_str)
        price_str = re.sub(r'\s', '', price_str)
        
        if not price_str:
            return 0.0
        
        # Türk formatı: "1.859,12" (nokta binlik, virgül ondalık)
        # Örnekler: "1.859,12" -> 1859.12, "174,900" -> 174900, "174.900" -> 174900
        
        # Hem nokta hem virgül varsa
        if ',' in price_str and '.' in price_str:
            # Son virgülden sonraki kısım ondalık mı kontrol et
            parts = price_str.rsplit(',', 1)
            if len(parts) == 2:
                decimal_part = parts[1]
                # Eğer virgülden sonra 1-2 rakam varsa ondalık kısımdır
                if len(decimal_part) <= 2 and decimal_part.isdigit():
                    # Türk formatı: "1.859,12" -> 1859.12
                    price_str = price_str.replace('.', '').replace(',', '.')
                else:
                    # Virgül binlik ayracı olabilir: "174,900" -> 174900
                    price_str = price_str.replace(',', '').replace('.', '')
            else:
                price_str = price_str.replace(',', '').replace('.', '')
        # Sadece virgül varsa
        elif ',' in price_str:
            parts = price_str.rsplit(',', 1)
            if len(parts) == 2:
                decimal_part = parts[1]
                # Eğer virgülden sonra 1-2 rakam varsa ondalık kısımdır
                if len(decimal_part) <= 2 and decimal_part.isdigit():
                    # Türk formatı: "859,12" -> 859.12
                    price_str = price_str.replace(',', '.')
                else:
                    # Virgül binlik ayracı: "174,900" -> 174900
                    price_str = price_str.replace(',', '')
            else:
                price_str = price_str.replace(',', '')
        # Sadece nokta varsa
        elif '.' in price_str:
            # Nokta binlik ayracı olabilir: "1.859" -> 1859
            # Ama ondalık da olabilir: "859.12" -> 859.12
            # Son noktadan sonraki kısım kontrol et
            parts = price_str.rsplit('.', 1)
            if len(parts) == 2:
                decimal_part = parts[1]
                # Eğer son noktadan sonra 1-2 rakam varsa ondalık kısımdır
                if len(decimal_part) <= 2 and decimal_part.isdigit():
                    # Ondalık: "859.12" -> 859.12
                    pass  # Olduğu gibi bırak
                else:
                    # Binlik ayracı: "1.859" -> 1859
                    price_str = price_str.replace('.', '')
            else:
                price_str = price_str.replace('.', '')
        
        try:
            price = float(price_str)
            # Makul fiyat aralığı kontrolü (10 TL - 10 milyon TL)
            if price < 10 or price > 10000000:
                return 0.0
            return price
        except:
            return 0.0

    def _resolve_url(self, url: str, base_url) -> str:
        """Relative URL'yi absolute URL'ye çevir"""
        if not url:
            return None
        if url.startswith('http://') or url.startswith('https://'):
            return url
        if url.startswith('//'):
            return f"{base_url.scheme}:{url}"
        if url.startswith('/'):
            return f"{base_url.scheme}://{base_url.netloc}{url}"
        return f"{base_url.scheme}://{base_url.netloc}/{url}"

    def parse_telegram_message(self, message_text: str, entities: List = None, button_urls: List = None) -> Dict:
        """Telegram mesajını parse et"""
        deal = {
            'title': '',
            'price': 0.0,
            'store': '',
            'category': 'tumu',  # Varsayılan kategori 'tumu' (veya 'diger') olarak değiştirildi.
            'link': '',
            'description': message_text
        }

        # URL'leri bul (öncelik sırası: butonlar > entities > text)
        urls = []
        
        # 1. Buton URL'lerini ekle (en öncelikli)
        if button_urls:
            urls.extend(button_urls)
        
        # 2. Entity URL'lerini ekle
        if entities:
            for entity in entities:
                if hasattr(entity, 'url'):
                    if entity.url and entity.url not in urls:
                        urls.append(entity.url)
        
        # 3. Text'ten URL'leri bul
        url_pattern = r'https?://[^\s]+'
        text_urls = re.findall(url_pattern, message_text)
        for url in text_urls:
            if url not in urls:
                urls.append(url)
        
        if urls:
            deal['link'] = urls[0]

        # Fiyat bul
        price_patterns = [
            r'(?:toplam|total|fiyat|price)[\s:]+(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)',
            r'(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*(?:TL|₺)',
            r'(?:₺|TL)\s*(\d{1,3}(?:[.,\s]\d{3})*(?:[.,]\d{2})?)',
        ]
        for pattern in price_patterns:
            match = re.search(pattern, message_text, re.I)
            if match:
                price = self._parse_price(match.group(1))
                if price > 0:
                    deal['price'] = price
                    break

        # Mağaza bul
        store_patterns = [
            r'(?:hepsiburada|trendyol|n11|gittigidiyor|amazon|vatan|mediamarkt|teknosa)',
        ]
        for pattern in store_patterns:
            match = re.search(pattern, message_text, re.I)
            if match:
                store_name = match.group(0).lower()
                store_map = {
                    'hepsiburada': 'Hepsiburada',
                    'trendyol': 'Trendyol',
                    'n11': 'N11',
                    'gittigidiyor': 'GittiGidiyor',
                    'amazon': 'Amazon',
                    'vatan': 'Vatan Bilgisayar',
                    'mediamarkt': 'MediaMarkt',
                    'teknosa': 'Teknosa',
                }
                deal['store'] = store_map.get(store_name, store_name.capitalize())
                break

        # URL'den domain adını al (henüz store bulunamadıysa)
        if not deal['store'] and deal['link']:
            try:
                hostname = urlparse(deal['link']).hostname
                if not hostname:
                    deal['store'] = 'Bilinmeyen Mağaza'
                    return deal
                
                hostname = hostname.replace('www.', '').lower()
                
                # Bilinen mağazalar
                if 'hepsiburada' in hostname:
                    deal['store'] = 'Hepsiburada'
                elif 'trendyol' in hostname:
                    deal['store'] = 'Trendyol'
                elif 'n11' in hostname or 'n11.com' in hostname:
                    deal['store'] = 'N11'
                elif 'gittigidiyor' in hostname:
                    deal['store'] = 'GittiGidiyor'
                elif 'amazon' in hostname:
                    deal['store'] = 'Amazon'
                elif 'vatan' in hostname:
                    deal['store'] = 'Vatan Bilgisayar'
                elif 'mediamarkt' in hostname:
                    deal['store'] = 'MediaMarkt'
                elif 'teknosa' in hostname:
                    deal['store'] = 'Teknosa'
                elif 'google' in hostname or 'youtube' in hostname:
                    # Google/Youtube linkleri genellikle redirect linkleridir, store bilgisi yok
                    deal['store'] = 'Bilinmeyen Mağaza'
                else:
                    # Diğer siteler için domain adını al
                    domain_parts = hostname.split('.')
                    if len(domain_parts) >= 2:
                        # Örnek: "example.com.tr" -> "Example"
                        main_domain = domain_parts[-2] if domain_parts[-1] in ['com', 'net', 'org', 'tr'] else domain_parts[0]
                        deal['store'] = main_domain.capitalize()
                    else:
                        deal['store'] = domain_parts[0].capitalize() if domain_parts else 'Bilinmeyen Mağaza'
            except Exception as e:
                logger.warning(f"Store çıkarma hatası: {e}")
                deal['store'] = 'Bilinmeyen Mağaza'

        # Başlık bul
        lines = [line.strip() for line in message_text.split('\n') if line.strip()]
        if lines:
            title = lines[0]
            title = re.sub(url_pattern, '', title).strip()
            if len(title) > 100:
                title = title[:97] + '...'
            deal['title'] = title or 'Fırsat'

        return deal

    def send_fcm_notification(self, deal_data: dict):
        """Yeni fırsat için FCM bildirimi gönder"""
        try:
            # Bildirim içeriği
            title = "🔥 Yeni Sıcak Fırsat!"
            body = f"{deal_data['title']}\n💰 {deal_data['price']} TL"
            image_url = deal_data.get('imageUrl', '')
            
            # 1. Kategoriye özel bildirim (topic: category_{categoryId})
            category_topic = f"category_{deal_data['category']}"
            
            if USE_FIREBASE_ADMIN:
                # Kategori bildirimi
                message = messaging.Message(
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                        image=image_url if image_url else None
                    ),
                    data={
                        'dealId': deal_data.get('id', ''),  # ID sonradan eklenecek
                        'type': 'deal',
                        'category': deal_data['category'],
                        'click_action': 'FLUTTER_NOTIFICATION_CLICK'
                    },
                    topic=category_topic
                )
                response = messaging.send(message)
                logger.info(f"📨 Kategori bildirimi gönderildi ({category_topic}): {response}")
                
                # Genel bildirim (isteğe bağlı, çok fazla olabilir)
                # topic: all_deals
                # message_all = ...
                # messaging.send(message_all)
                
            else:
                # REST API ile gönderim (Termux için)
                self._send_fcm_rest(category_topic, title, body, deal_data)
                
        except Exception as e:
            logger.error(f"❌ Bildirim gönderme hatası: {e}")

    def _send_fcm_rest(self, topic: str, title: str, body: str, data: dict):
        """REST API ile FCM bildirimi gönder"""
        # Not: REST API ile FCM gönderimi için server key gerekir veya
        # OAuth2 token ile FCM v1 API kullanılmalıdır.
        # Şimdilik sadece log basıyoruz, çünkü Termux'ta service account ile
        # FCM v1 API kullanımı biraz karmaşık olabilir.
        logger.warning("⚠️ REST API ile bildirim gönderimi henüz aktif değil")

    async def process_message(self, message, channel_username: str):
        """Mesajı işle ve Firebase'e kaydet"""
        try:
            message_text = message.message
            message_id = message.id

            if not message_text:
                return

            logger.info(f"\n📨 Mesaj {message_id} işleniyor...")
            logger.info(f"   Media var mı: {bool(message.media)}")

            # Reply markup'dan (butonlardan) URL'leri çıkar
            button_urls = []
            if hasattr(message, 'reply_markup') and message.reply_markup:
                try:
                    if hasattr(message.reply_markup, 'rows'):
                        for row in message.reply_markup.rows:
                            if hasattr(row, 'buttons'):
                                for button in row.buttons:
                                    if hasattr(button, 'url') and button.url:
                                        button_urls.append(button.url)
                except Exception as e:
                    logger.warning(f"Reply markup parse hatası: {e}")

            # Mesajı parse et (buton URL'lerini de ekle)
            parsed_deal = self.parse_telegram_message(message_text, message.entities if hasattr(message, 'entities') else None, button_urls)

            if not parsed_deal['title'] or not parsed_deal['link']:
                logger.warning(f"Mesaj {message_id} eksik bilgi içeriyor, atlanıyor")
                return

            # Bu mesajı daha önce işledik mi kontrol et
            chat_identifier = channel_username.replace('@', '') if channel_username.startswith('@') else channel_username
            
            if USE_FIREBASE_ADMIN:
                # firebase-admin kullan (PC için)
                existing_deals = db.collection('deals').where('telegramMessageId', '==', message_id).where('telegramChatUsername', '==', chat_identifier).limit(1).get()
                if len(list(existing_deals)) > 0:
                    logger.info(f"Mesaj {message_id} zaten işlenmiş, atlanıyor")
                    return
            else:
                # Firebase REST API kullan (Termux için) - DÜZELTİLMİŞ
                existing_deals = firebase_rest_api.firestore_query(
                    'deals',
                    filters=[
                        ('telegramMessageId', 'EQUAL', message_id),  # str() kaldırıldı, direkt integer
                        ('telegramChatUsername', 'EQUAL', chat_identifier)
                    ],
                    limit=1
                )
                if len(existing_deals) > 0:
                    logger.info(f"Mesaj {message_id} zaten işlenmiş, atlanıyor")
                    return

            # Görsel çek
            image_url = ''
            link_data = None  # HTML ve final_url'i saklamak için
            
            # Blob URL kontrolü
            has_blob_url = 'blob:' in message_text
            
            # Öncelik 1: Telegram media'dan çek
            if message.media or has_blob_url:
                logger.info("📷 Telegram media'dan görsel çekiliyor...")
                telegram_image = await self.fetch_image_from_telegram(message, chat_identifier, message_id)
                if telegram_image:
                    image_url = telegram_image
                    logger.info("✅ Telegram media'dan görsel başarıyla çekildi")

            # Öncelik 2: Linkten çek
            if not image_url and parsed_deal['link']:
                logger.info(f"🔗 Linkten görsel çekiliyor: {parsed_deal['link']}")
                link_data = await self.fetch_link_data(parsed_deal['link'])
                if link_data and link_data.get('html'):
                    final_url = link_data.get('final_url', parsed_deal['link'])
                    link_image = self.extract_image_from_html(link_data['html'], final_url)
                    if link_image:
                        image_url = link_image
                        logger.info(f"✅ Linkten görsel başarıyla çekildi: {image_url}")
                    else:
                        logger.warning("⚠️ Linkten görsel bulunamadı")
                else:
                    logger.warning("⚠️ Link HTML'i çekilemedi")

            # Kategori çek - Linkten kategori bilgisini çıkar (öncelik sırası: HTML > URL > Başlık)
            category_found = False
            if parsed_deal['link']:
                logger.info(f"🏷️ Linkten kategori çekiliyor: {parsed_deal['link']}")
                # HTML zaten görsel için çekildiyse tekrar çekme
                if not link_data:
                    link_data = await self.fetch_link_data(parsed_deal['link'])
                
                # 1. Öncelik: HTML'den kategori çıkar
                if link_data and link_data.get('html'):
                    final_url = link_data.get('final_url', parsed_deal['link'])
                    category_from_html = self.extract_category_from_html(link_data['html'], final_url, parsed_deal['title'])
                    if category_from_html:
                        logger.info(f"✅ HTML'den kategori bulundu: {category_from_html}")
                        parsed_deal['category'] = category_from_html
                        category_found = True
                
                # 2. HTML çekilemediyse veya kategori bulunamadıysa URL'den çıkar
                if not category_found:
                    category_from_url = self.extract_category_from_url(parsed_deal['link'], parsed_deal['title'])
                    if category_from_url:
                        logger.info(f"✅ URL'den kategori bulundu: {category_from_url}")
                        parsed_deal['category'] = category_from_url
                        category_found = True
                
                # 3. URL'den de bulunamadıysa başlıktan çıkar
                if not category_found:
                    category_from_title = self.extract_category_from_title(parsed_deal['title'])
                    if category_from_title:
                        logger.info(f"✅ Başlıktan kategori bulundu: {category_from_title}")
                        parsed_deal['category'] = category_from_title
                        category_found = True
            else:
                # Link yoksa sadece başlıktan kategori çıkarmayı dene
                category_from_title = self.extract_category_from_title(parsed_deal['title'])
                if category_from_title:
                    logger.info(f"✅ Başlıktan kategori bulundu: {category_from_title}")
                    parsed_deal['category'] = category_from_title
                    category_found = True
            
            # Kategori bulunamadıysa varsayılan kategoriyi kullan
            if not category_found:
                logger.info(f"📝 Kategori bulunamadı, varsayılan kategori kullanılıyor: {parsed_deal['category']}")

            # Store bilgisini final_url'den güncelle (redirect linklerini handle et)
            if link_data and link_data.get('final_url') and link_data['final_url'] != parsed_deal['link']:
                logger.info(f"🔄 Redirect tespit edildi: {parsed_deal['link']} -> {link_data['final_url']}")
                final_url = link_data['final_url']
                try:
                    hostname = urlparse(final_url).hostname
                    if hostname:
                        hostname = hostname.replace('www.', '').lower()
                        if 'hepsiburada' in hostname:
                            parsed_deal['store'] = 'Hepsiburada'
                        elif 'trendyol' in hostname:
                            parsed_deal['store'] = 'Trendyol'
                        elif 'n11' in hostname or 'n11.com' in hostname:
                            parsed_deal['store'] = 'N11'
                        elif 'gittigidiyor' in hostname:
                            parsed_deal['store'] = 'GittiGidiyor'
                        elif 'amazon' in hostname:
                            parsed_deal['store'] = 'Amazon'
                        elif 'vatan' in hostname:
                            parsed_deal['store'] = 'Vatan Bilgisayar'
                        elif 'mediamarkt' in hostname:
                            parsed_deal['store'] = 'MediaMarkt'
                        elif 'teknosa' in hostname:
                            parsed_deal['store'] = 'Teknosa'
                        logger.info(f"✅ Store güncellendi: {parsed_deal['store']}")
                except Exception as e:
                    logger.warning(f"Store güncelleme hatası: {e}")
            
            # Fiyat çek - HER ZAMAN linkten çekmeyi dene (öncelikli)
            message_price = parsed_deal['price']  # Mesajdan parse edilen fiyat (yedek olarak sakla)
            if parsed_deal['link']:
                logger.info(f"💰 Linkten fiyat çekiliyor: {parsed_deal['link']}")
                # HTML zaten görsel için çekildiyse tekrar çekme
                if not link_data:
                    link_data = await self.fetch_link_data(parsed_deal['link'])
                if link_data and link_data.get('html'):
                    final_url = link_data.get('final_url', parsed_deal['link'])
                    html_data = self.extract_html_data(link_data['html'], final_url)
                    price_found = html_data.get('price', 0.0)
                    
                    if price_found > 0:
                        parsed_deal['price'] = price_found
                        parsed_deal['originalPrice'] = html_data.get('original_price', 0.0)
                        logger.info(f"✅ Linkten fiyat bulundu: {price_found} TL")
                    else:
                        logger.warning("⚠️ Linkten fiyat bulunamadı, mesajdan parse edilen fiyat kullanılıyor")
                        # Linkten bulunamazsa mesajdan parse edilen fiyatı kullan
                        if message_price > 0:
                            logger.info(f"📝 Mesajdan parse edilen fiyat kullanılıyor: {message_price} TL")
                            parsed_deal['price'] = message_price
                else:
                    logger.warning("⚠️ Link HTML'i çekilemedi, mesajdan parse edilen fiyat kullanılıyor")
                    # HTML çekilemezse mesajdan parse edilen fiyatı kullan
                    if message_price > 0:
                        logger.info(f"📝 Mesajdan parse edilen fiyat kullanılıyor: {message_price} TL")
                        parsed_deal['price'] = message_price
            else:
                logger.warning("⚠️ Link yok, mesajdan parse edilen fiyat kullanılıyor")
                if message_price > 0:
                    logger.info(f"📝 Mesajdan parse edilen fiyat kullanılıyor: {message_price} TL")

            # --- AI ANALİZİ (GEMINI) ---
            # HTML parsing ve Regex sonrası son kontrol ve iyileştirme
            try:
                # AI için metni hazırla
                ai_input_text = message_text
                if parsed_deal['title']:
                    ai_input_text = f"Ürün Başlığı: {parsed_deal['title']}\n\nMesaj: {message_text}"
                
                logger.info("🧠 AI Analizi başlatılıyor...")
                ai_analysis = await self.analyze_deal_with_ai(ai_input_text, parsed_deal['link'])
                
                if ai_analysis:
                    # 1. Başlık iyileştirme
                    if ai_analysis.get('title') and len(ai_analysis['title']) > 5:
                        parsed_deal['title'] = ai_analysis['title']
                    
                    # 2. Kategori düzeltme (AI genelde daha iyidir)
                    if ai_analysis.get('category'):
                        parsed_deal['category'] = ai_analysis['category']
                    
                    # 3. Mağaza düzeltme
                    if ai_analysis.get('store'):
                        parsed_deal['store'] = ai_analysis['store']
                    
                    # 4. Fiyat Mantığı (Kritik)
                    # Eğer HTML'den zaten güvenilir bir fiyat (parsed_deal['price']) bulduysak, AI'nın bunu bozmasına izin verme.
                    # Sadece fiyat 0 ise AI fiyatını kullan.
                    
                    current_price = parsed_deal.get('price', 0.0)
                    ai_price = ai_analysis.get('price', 0.0)
                    ai_original_price = ai_analysis.get('original_price', 0.0)
                    
                    if current_price > 20:
                        # Zaten HTML'den fiyat bulduk (Amazon vb.). Koru.
                        # Ancak originalPrice eksikse AI'dan tamamla
                        if parsed_deal.get('originalPrice', 0.0) == 0 and ai_original_price > current_price:
                            parsed_deal['originalPrice'] = ai_original_price
                            logger.info(f"✅ Fiyat HTML'den korundu ({current_price}), Eski Fiyat AI'dan eklendi ({ai_original_price})")
                    elif ai_price > 0:
                        # HTML'den fiyat bulamadık, AI fiyatını kullan
                        parsed_deal['price'] = ai_price
                        parsed_deal['originalPrice'] = ai_original_price
                        logger.info(f"✅ Fiyat AI'dan alındı: {ai_price} TL (Eski: {ai_original_price})")
            except Exception as e:
                logger.error(f"AI Entegrasyon Hatası: {e}")

            # Final URL'i kaydet (redirect linklerini handle etmek için)
            final_link = parsed_deal['link']
            if link_data and link_data.get('final_url'):
                final_link = link_data['final_url']
                logger.info(f"🔗 Final URL kullanılıyor: {final_link}")
            
            # Fiyat ve İndirim Hesaplama
            price = parsed_deal.get('price', 0.0) or 0.0
            # parsed_deal'de hem 'originalPrice' hem de 'original_price' olabilir, ikisini de kontrol et
            original_price = parsed_deal.get('originalPrice', 0.0) or parsed_deal.get('original_price', 0.0) or 0.0
            discount_rate = 0
            
            # Eğer eski fiyat varsa indirim oranını hesapla
            if original_price > price > 0:
                discount_rate = int(((original_price - price) / original_price) * 100)
                logger.info(f"💰 İndirim Oranı Hesaplandı: %{discount_rate} (Eski: {original_price} TL, Yeni: {price} TL)")
            else:
                logger.warning(f"⚠️ İndirim oranı hesaplanamadı: original_price={original_price}, price={price}")
            
            # Firebase'e kaydet
            deal_data = {
                'title': parsed_deal['title'],
                'price': price,
                'originalPrice': original_price,
                'discountRate': discount_rate,
                'store': parsed_deal['store'] or 'Bilinmeyen Mağaza',
                'category': parsed_deal['category'],
                'link': final_link,  # Final URL'i kullan (redirect'leri handle et)
                'imageUrl': image_url or '',
                'description': parsed_deal['description'],
                'hotVotes': 0,
                'coldVotes': 0,
                'commentCount': 0,
                'postedBy': f"telegram_channel_{chat_identifier}",
                'createdAt': (firestore.SERVER_TIMESTAMP if USE_FIREBASE_ADMIN else datetime.utcnow()),
                'isEditorPick': False,
                'isApproved': False,
                'isExpired': False,
                'hotVoters': [],
                'coldVoters': [],
                'source': 'telegram',
                'telegramMessageId': message_id,
                'telegramChatId': str(getattr(message.peer_id, 'channel_id', '') or getattr(message.peer_id, 'chat_id', '') or ''),
                'telegramChatType': 'channel',
                'telegramChatTitle': channel_username,
                'telegramChatUsername': chat_identifier,
                'rawMessage': message_text,
            }

            if USE_FIREBASE_ADMIN:
                # firebase-admin kullan (PC için)
                doc_ref = db.collection('deals').document()
                doc_ref.set(deal_data)
                doc_id = doc_ref.id
            else:
                # Firebase REST API kullan (Termux için)
                # SERVER_TIMESTAMP'i datetime'a çevir
                if 'createdAt' in deal_data and hasattr(deal_data['createdAt'], '__name__') and deal_data['createdAt'].__name__ == 'SERVER_TIMESTAMP':
                    deal_data['createdAt'] = datetime.utcnow()
                doc_id = firebase_rest_api.firestore_add('deals', deal_data)
            
            # ID'yi deal_data'ya ekle (bildirim için)
            deal_data['id'] = doc_id
            
            logger.info(f"✅ Deal Firebase'e kaydedildi: {doc_id}")
            logger.info(f"   📊 Başlık: {deal_data['title']}")
            logger.info(f"   💰 Fiyat: {deal_data['price']} TL")
            logger.info(f"   🖼️ Görsel: {deal_data['imageUrl'] or 'YOK'}")
            logger.info(f"   🔗 Link: {deal_data['link']}")
            
            # Bildirim artık Cloud Functions üzerinden otomatik gönderiliyor
            # self.send_fcm_notification(deal_data)
            logger.info(f"🚀 Bildirim Cloud Functions'a devredildi")

        except Exception as e:
            logger.error(f"❌ Mesaj işleme hatası: {e}", exc_info=True)

    async def fetch_channel_messages(self, channel_username: str):
        """Kanal mesajlarını çek"""
        try:
            logger.info(f"📡 Kanal/Grup bulunuyor: {channel_username}")
            
            entity = None
            
            # Kanal/Grup bulma mantığı
            if channel_username.startswith('@'):
                # Username ile kanal
                entity = await self.client.get_entity(channel_username)
            elif channel_username.startswith('-'):
                # Negatif sayı = Grup ID
                numeric_id = int(channel_username)
                
                # Önce sayısal ID olarak dene
                try:
                    entity = await self.client.get_entity(numeric_id)
                except Exception as e1:
                    logger.warning(f"Direkt ID ile bulunamadı, supergroup formatı deneniyor...")
                    # Eğer -100 ile başlamıyorsa, supergroup formatına çevir
                    if not channel_username.startswith('-100'):
                        try:
                            numeric_part = channel_username.replace('-', '')
                            supergroup_id = int('-100' + numeric_part)
                            entity = await self.client.get_entity(supergroup_id)
                        except Exception as e2:
                            logger.warning(f"Supergroup formatı ile bulunamadı, InputPeerChat deneniyor...")
                            # Son çare: InputPeerChat kullan
                            from telethon.tl.types import InputPeerChat
                            chat_id = abs(numeric_id)
                            entity = await self.client.get_entity(InputPeerChat(chat_id=chat_id))
                    else:
                        raise e1
            else:
                # Sayısal ID veya username
                try:
                    numeric_id = int(channel_username)
                    entity = await self.client.get_entity(numeric_id)
                except ValueError:
                    # Username olarak dene (@ olmadan)
                    entity = await self.client.get_entity('@' + channel_username)
            
            logger.info(f"✅ Kanal/Grup bulundu: {getattr(entity, 'title', None) or channel_username}")

            # Chat identifier'ı oluştur
            chat_identifier = channel_username.replace('@', '') if channel_username.startswith('@') else channel_username
            
            # Son işlenen mesaj ID'sini al
            last_message_id = self.get_last_processed_message_id(chat_identifier)
            
            # Her zaman son N mesajı çek (daha güvenilir)
            # Telethon'un offset_id/min_id parametreleri güvenilir değil
            fetch_limit = 3 if last_message_id else 5  # İlk çalıştırmada 5, sonra 3
            
            logger.info(f"📥 Son {fetch_limit} mesaj çekiliyor...")
            all_messages = await self.client.get_messages(entity, limit=fetch_limit)
            
            # Çekilen mesaj ID'lerini logla
            if all_messages:
                message_ids = [m.id for m in all_messages if m.message]
                logger.info(f"📋 Çekilen mesaj ID'leri: {message_ids}")
                logger.info(f"📊 En yüksek mesaj ID: {max(message_ids) if message_ids else 'YOK'}")
            
            # Son mesaj ID'sinden büyük olanları filtrele (yeni mesajlar)
            if last_message_id:
                logger.info(f"📌 Son işlenen mesaj ID: {last_message_id}")
                messages = [m for m in all_messages if m.id > last_message_id and m.message]
                logger.info(f"🔍 {len(all_messages)} mesaj çekildi, {len(messages)} tanesi yeni (ID > {last_message_id})")
                if messages:
                    new_ids = [m.id for m in messages]
                    logger.info(f"✨ Yeni mesaj ID'leri: {new_ids}")
            else:
                logger.info("📌 İlk çalıştırma - tüm mesajlar işlenecek")
                messages = [m for m in all_messages if m.message]
            
            if not messages:
                logger.info("ℹ️ Yeni mesaj yok")
                return
            
            logger.info(f"📨 {len(messages)} yeni mesaj bulundu")

            # Mesajları ID'ye göre sırala (en eski önce - sırayla işlemek için)
            messages = sorted(messages, key=lambda m: m.id)
            
            # Her mesajı işle (duplicate kontrolü process_message içinde yapılıyor)
            processed_count = 0
            skipped_count = 0
            last_processed_id = last_message_id  # Başlangıç değeri
            
            for message in messages:
                if message.message:
                    message_id = message.id
                    # Duplicate kontrolü (process_message içinde de var ama burada da kontrol edelim)
                    chat_id = chat_identifier
                    if USE_FIREBASE_ADMIN:
                        existing = list(db.collection('deals').where('telegramMessageId', '==', message_id).where('telegramChatUsername', '==', chat_id).limit(1).get())
                        if existing:
                            logger.info(f"⏭️ Mesaj {message_id} zaten işlenmiş (ön kontrol), atlanıyor")
                            skipped_count += 1
                            last_processed_id = max(last_processed_id or 0, message_id)  # ID'yi güncelle
                            continue
                    else:
                        existing = firebase_rest_api.firestore_query(
                            'deals',
                            filters=[
                                ('telegramMessageId', 'EQUAL', message_id),
                                ('telegramChatUsername', 'EQUAL', chat_id)
                            ],
                            limit=1
                        )
                        if existing:
                            logger.info(f"⏭️ Mesaj {message_id} zaten işlenmiş (ön kontrol), atlanıyor")
                            skipped_count += 1
                            last_processed_id = max(last_processed_id or 0, message_id)  # ID'yi güncelle
                            continue
                    
                    # Mesajı işle
                    try:
                        await self.process_message(message, channel_username)
                        last_processed_id = max(last_processed_id or 0, message_id)
                        processed_count += 1
                        logger.info(f"✅ Mesaj {message_id} işlendi ({processed_count}/{len(messages)})")
                    except Exception as e:
                        logger.error(f"❌ Mesaj {message_id} işlenirken hata: {e}")
                        # Hata olsa bile ID'yi güncelle (tekrar denememek için)
                        last_processed_id = max(last_processed_id or 0, message_id)
                    
                    await asyncio.sleep(1)  # Rate limiting
            
            # Son işlenen mesaj ID'sini kaydet (işlenen veya atlanan en büyük ID)
            if last_processed_id and last_processed_id != last_message_id:
                self.save_last_processed_message_id(chat_identifier, last_processed_id)
                logger.info(f"✅ {processed_count} mesaj işlendi, {skipped_count} mesaj atlandı, son mesaj ID: {last_processed_id}")
            elif last_message_id:
                # Yeni mesaj yoksa, mevcut ID'yi koru
                logger.info(f"ℹ️ Yeni mesaj yok (tümü zaten işlenmiş), son mesaj ID korunuyor: {last_message_id}")

        except Exception as e:
            logger.error(f"❌ Kanal mesajları çekilirken hata: {e}", exc_info=True)

    async def message_handler(self, event):
        """Yeni mesaj geldiğinde çalışacak handler"""
        try:
            # Mesajın geldiği sohbeti (kanal/grup) al
            chat = await event.get_chat()
            
            # Kanal ismini veya başlığını belirle
            if hasattr(chat, 'username') and chat.username:
                channel_name = f"@{chat.username}"
            elif hasattr(chat, 'title'):
                channel_name = chat.title
            else:
                channel_name = str(chat.id)

            logger.info(f"🔔 YENİ MESAJ ALGILANDI -> Kanal: {channel_name} | ID: {event.message.id}")
            
            # Mevcut işleme fonksiyonunu çağır
            await self.process_message(event.message, channel_name)
            
        except Exception as e:
            logger.error(f"❌ Handler hatası: {e}", exc_info=True)

    async def run(self):
        """Bot'u çalıştır - Event Listener Modu"""
        await self.initialize()
        
        # Kanalları hazırla
        target_channels = [c.strip() for c in self.channels if c.strip()]
        
        if not target_channels:
            logger.error("❌ İzlenecek kanal listesi boş! .env dosyasını kontrol edin.")
            return

        logger.info("==================================================")
        logger.info(f"🎧 EVENT LISTENER BAŞLATILIYOR")
        logger.info(f"📡 İzlenen Kanal Sayısı: {len(target_channels)}")
        logger.info(f"📋 Kanallar: {target_channels}")
        logger.info("==================================================")

        # Event handler'ı kaydet
        # Kanal listesini çözümle ve sadece geçerli olanları dinle
        resolved_chats = []
        for channel in target_channels:
            try:
                # String ID'leri integer'a çevirmeyi dene
                if channel.startswith('-100'):
                    entity = int(channel)
                elif channel.startswith('-'):
                    # -33... gibi ID'ler için
                    try:
                        entity = int(channel)
                    except:
                        entity = channel
                else:
                    entity = channel

                # Entity'nin geçerli olup olmadığını kontrol et
                # get_input_entity önbellekten veya sunucudan kontrol eder
                        try:
                    await self.client.get_input_entity(entity)
                    resolved_chats.append(entity)
                    logger.info(f"✅ Kanal takibe alındı: {channel}")
                except ValueError:
                    logger.warning(f"⚠️ Kanal bulunamadı veya erişilemiyor (Atlanıyor): {channel}")
                    # Yine de listeye eklemeyi deneyelim, belki sonradan bulunur (ama event listener patlayabilir)
                    # resolved_chats.append(entity) 
                        except Exception as e:
                logger.error(f"❌ Kanal çözümlenirken hata ({channel}): {e}")

        if not resolved_chats:
            logger.error("❌ Hiçbir kanal çözümlenemedi! Lütfen kanal ID'lerini kontrol edin.")
            return

        logger.info(f"📡 Aktif Dinlenen Kanal Sayısı: {len(resolved_chats)}")

        @self.client.on(events.NewMessage(chats=resolved_chats))
        async def wrapper(event):
            await self.message_handler(event)

        try:
            # Başlangıçta son mesajları bir kez kontrol etmek isterseniz burayı açabilirsiniz:
            # logger.info("🔄 Başlangıç kontrolü yapılıyor...")
            # for channel in target_channels:
            #     await self.fetch_channel_messages(channel)
            
            logger.info("✅ Bot aktif ve dinliyor... (Durdurmak için CTRL+C)")
            await self.client.run_until_disconnected()
                
            except KeyboardInterrupt:
            logger.info("🛑 Bot kullanıcı tarafından durduruldu")
            except Exception as e:
            logger.error(f"❌ Bot kritik hata ile durdu: {e}", exc_info=True)


async def main():
    """Ana fonksiyon"""
    # Logs klasörünü oluştur
    os.makedirs('logs', exist_ok=True)
    
    bot = TelegramDealBot()
    await bot.run()


if __name__ == '__main__':
    asyncio.run(main())