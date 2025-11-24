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
                
                # 1. İndirimli Fiyatı (Price To Pay) Bul
                price_selectors = [
                    '.priceToPay span.a-offscreen', 
                    '.priceToPay',
                    '#corePriceDisplay_desktop_feature_div .a-price-whole',
                    '#apex_desktop .a-price-whole',
                    '#corePrice_feature_div .a-price.priceToPay .a-offscreen'
                ]
                
                for selector in price_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        price = self._parse_price(price_text)
                        if price >= 20:
                            data['price'] = price
                            logger.info(f"✅ Amazon İndirimli Fiyat Bulundu: {price} TL (Selector: {selector})")
                            break
                
                # 2. Orijinal Fiyatı (Basis Price / List Price) Bul
                original_selectors = [
                    '.basisPrice span.a-offscreen',
                    '.basisPrice',
                    'span.a-price.a-text-price span.a-offscreen',
                    '.a-text-strike',
                    'span[data-a-strike="true"] span.a-offscreen'
                ]
                
                for selector in original_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price_text = elem.get_text(strip=True)
                        original = self._parse_price(price_text)
                        if original > data['price'] and original > 20:
                            data['original_price'] = original
                            logger.info(f"✅ Amazon Orijinal Fiyat Bulundu: {original} TL (Selector: {selector})")
                            break
                
                return data

            # --- GENEL MANTIK (Diğer Siteler) ---
            # 1. JSON-LD Schema
            json_ld_scripts = soup.find_all('script', type='application/ld+json')
            for script in json_ld_scripts:
                try:
                    if not script.string: continue
                    js_data = json.loads(script.string)
                    
                    def find_price_recursive(obj):
                        if isinstance(obj, dict):
                            if 'price' in obj and (isinstance(obj['price'], (int, float, str))):
                                return self._parse_price(str(obj['price']))
                            if 'offers' in obj:
                                return find_price_recursive(obj['offers'])
                            if 'lowPrice' in obj:
                                return self._parse_price(str(obj['lowPrice']))
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
                except Exception:
                    continue

            # 2. Meta tags
            meta_selectors = [
                {'property': 'product:price:amount'},
                {'property': 'og:price:amount'},
                {'name': 'price'},
                {'itemprop': 'price'},
            ]
            for selector in meta_selectors:
                price_meta = soup.find('meta', selector)
                if price_meta and price_meta.get('content'):
                    price = self._parse_price(price_meta.get('content'))
                    if price >= 10:
                        data['price'] = price
                        logger.info(f"✅ Fiyat bulundu (Meta {selector}): {price} TL")
                        return data

            # 3. Genel HTML Selectors
            general_selectors = [
                '.product-price', '.price', '.current-price', 
                'span[itemprop="price"]', '.amount', 
                'div[class*="price"]', 'span[class*="price"]'
            ]
            
            for selector in general_selectors:
                elem = soup.select_one(selector)
                if elem:
                    price = self._parse_price(elem.get_text(strip=True))
                    if price >= 10:
                        data['price'] = price
                        break

        except Exception as e:
            logger.error(f"HTML analiz hatası: {e}")
        
        return data


