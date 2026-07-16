import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Recursively search for keys or values containing specific keywords
def search_val(obj, path=""):
    results = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            current_path = f"{path}.{k}" if path else k
            if k in ["category", "categories", "categoryIds", "subCategoryIds", "categoryName", "name", "title"] and v:
                results.append((current_path, v))
            results.extend(search_val(v, current_path))
    elif isinstance(obj, list):
        for idx, item in enumerate(obj):
            current_path = f"{path}[{idx}]"
            results.extend(search_val(item, current_path))
    elif isinstance(obj, str):
        if len(obj) < 100 and any(keyword in obj.lower() for keyword in ["dondurma", "tatlı", "yiyecek", "atıştırmalık", "magnum"]):
            results.append((path, obj))
    return results

found = search_val(data)
print(f"Found {len(found)} references:")
for path, val in found[:100]:
    try:
        print(f"{path} = {str(val).encode('utf-8', errors='ignore').decode('cp1254', errors='ignore')}")
    except:
        pass
