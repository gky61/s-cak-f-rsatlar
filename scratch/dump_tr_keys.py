import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

tr = data.get("props", {}).get("pageProps", {}).get("_nextI18Next", {}).get("initialI18nStore", {}).get("tr", {})

def print_safe(text):
    try:
        print(text.encode('utf-8', errors='ignore').decode('cp1254', errors='ignore'))
    except:
        pass

for domain in ['getirx', 'market']:
    print(f"\nDOMAIN: {domain}")
    for k, v in tr.get(domain, {}).items():
        if isinstance(v, str) and len(v) < 200:
            print_safe(f"  {k}: {v}")
        elif isinstance(v, dict):
            print_safe(f"  {k}: {list(v.keys())}")
        else:
            print_safe(f"  {k}: {type(v)}")
