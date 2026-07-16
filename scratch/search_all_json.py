import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

target_ids = ['55bca8484dcda90c00e3aa80', '6a2682c191127d8011dd8f2c', '6a26ac61902fcb957601137d', '697c8609a5f2f92b12ca738b']

def search_id(obj, path=""):
    results = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            current_path = f"{path}.{k}" if path else k
            if isinstance(v, str) and v in target_ids:
                results.append((current_path, v))
            results.extend(search_id(v, current_path))
    elif isinstance(obj, list):
        for idx, item in enumerate(obj):
            current_path = f"{path}[{idx}]"
            if isinstance(item, str) and item in target_ids:
                results.append((current_path, item))
            results.extend(search_id(item, current_path))
    return results

found = search_id(data)
print(f"Found {len(found)} references to target IDs:")
for path, val in found:
    print(f"{path} = {val}")
