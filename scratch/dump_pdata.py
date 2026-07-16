import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

p_data = data.get("props", {}).get("pageProps", {}).get("initialState", {}).get("productDetail", {}).get("data", {})

def print_safe(text):
    try:
        print(text.encode('utf-8', errors='ignore').decode('cp1254', errors='ignore'))
    except:
        pass

for k, v in p_data.items():
    if k not in ['additionalPropertyTables', 'picURLs', 'squareThumbnailURL', 'shareLink']:
        print_safe(f"{k}: {v}")
