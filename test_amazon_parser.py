import asyncio
import os
import re
from curl_cffi.requests import AsyncSession
from bs4 import BeautifulSoup
from dotenv import load_dotenv
import google.generativeai as genai

# Load environment variables
load_dotenv()

URL = "https://www.amazon.com.tr/dp/B0BNTB9FL1?tag=firsatlar.co-39121-21&th=1"

async def fetch_html(url):
    print(f"Fetching URL: {url}")
    try:
        async with AsyncSession(impersonate="chrome110") as session:
            response = await session.get(url, timeout=30, allow_redirects=True)
            if response.status_code == 200:
                print(f"✅ HTML fetched ({len(response.text)} bytes)")
                return response.text
            else:
                print(f"❌ Failed with status {response.status_code}")
                return None
    except Exception as e:
        print(f"❌ Error fetching: {e}")
        return None

def extract_price_bs4(html):
    soup = BeautifulSoup(html, 'lxml')
    
    # Selectors to check
    selectors = [
        ('PriceToPay', 'span.priceToPay'),
        ('PriceToPay Offscreen', 'span.priceToPay span.a-offscreen'),
        ('BasisPrice', '.basisPrice'),
        ('BasisPrice Offscreen', 'span.a-price.a-text-price span.a-offscreen'),
        ('CorePrice Whole', '#corePriceDisplay_desktop_feature_div .a-price-whole'),
        ('Apex Price', '#apex_desktop .a-price-whole'),
    ]
    
    print("\n--- BeautifulSoup Analysis ---")
    for name, selector in selectors:
        element = soup.select_one(selector)
        if element:
            text = element.get_text(strip=True)
            print(f"Found {name}: '{text}'")
        else:
            print(f"Not found: {name}")

async def analyze_with_ai(html):
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("\n❌ GEMINI_API_KEY not found in .env")
        return

    genai.configure(api_key=api_key)
    model = genai.GenerativeModel('gemini-1.5-flash')
    
    # Clean HTML to reduce token count
    soup = BeautifulSoup(html, 'lxml')
    for tag in soup(['script', 'style', 'svg', 'path', 'noscript', 'iframe', 'footer', 'header']):
        tag.decompose()
    
    clean_text = soup.get_text(separator=' ', strip=True)[:30000] # Limit context
    
    prompt = f"""
    Analyze this Amazon product page text and extract the REAL price information.
    
    Context:
    - "Price To Pay" or the main big price is the current Deal Price.
    - "List Price" or crossed-out price is the Original Price.
    - IGNORE monthly installment prices (like "300 TL x 6 months").
    - IGNORE percentage numbers (like "%10").
    
    Text:
    {clean_text[:5000]}... (truncated)
    
    Output JSON only:
    {{
        "price": number,
        "original_price": number,
        "currency": "TL"
    }}
    """
    
    print("\n--- AI Analysis ---")
    try:
        response = await model.generate_content_async(prompt)
        print(f"AI Response: {response.text}")
    except Exception as e:
        print(f"AI Error: {e}")

async def main():
    html = await fetch_html(URL)
    if html:
        extract_price_bs4(html)
        await analyze_with_ai(html)

if __name__ == "__main__":
    asyncio.run(main())


