import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Recursively print all key-value pairs where value is a string containing "Magnum" or "Badem" or "Nogger" or "Paketi"
def print_matches(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            current_path = f"{path}.{k}" if path else k
            if isinstance(v, str) and any(x in v.lower() for x in ["magnum", "badem", "nogger", "paketi"]):
                print_safe(f"{current_path} = {v}")
            print_matches(v, current_path)
    elif isinstance(obj, list):
        for idx, item in enumerate(obj):
            current_path = f"{path}[{idx}]"
            if isinstance(item, str) and any(x in item.lower() for x in ["magnum", "badem", "nogger", "paketi"]):
                print_safe(f"{current_path} = {item}")
            print_matches(item, current_path)

def print_safe(text):
    try:
        print(text.encode('utf-8', errors='ignore').decode('cp1254', errors='ignore'))
    except:
        pass

print_matches(data)
