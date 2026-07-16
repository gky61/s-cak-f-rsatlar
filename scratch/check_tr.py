import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

tr = data.get("props", {}).get("pageProps", {}).get("_nextI18Next", {}).get("initialI18nStore", {}).get("tr", {})
print("tr keys:", list(tr.keys()))
for k in tr.keys():
    print(f"tr.{k} keys (first 10):", list(tr[k].keys())[:10])
