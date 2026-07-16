import urllib.request
import urllib.error

def test_url(url, label):
    print(f"Testing {label} URL: {url}")
    try:
        req = urllib.request.Request(
            url,
            headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
            }
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            print(f"  {label} Success! Status code: {response.status}")
            html = response.read().decode('utf-8', errors='ignore')
            print(f"  HTML length: {len(html)}")
            if "Chunkies" in html:
                print("  FOUND: 'Chunkies' in HTML!")
            else:
                print("  WARNING: 'Chunkies' NOT in HTML!")
    except urllib.error.HTTPError as e:
        print(f"  {label} HTTPError: {e.code} - {e.reason}")
        try:
            body = e.read().decode('utf-8', errors='ignore')
            print(f"  Error body preview (first 200 chars): {body[:200].strip()}")
        except Exception:
            pass
    except Exception as e:
        print(f"  {label} Error: {e}")

# Test direct
test_url('https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/', 'Direct')

# Test translate
test_url('https://getir-com.translate.goog/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/?_x_tr_sl=auto&_x_tr_tl=tr', 'Translate Proxy')
