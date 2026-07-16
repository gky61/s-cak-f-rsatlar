import re

with open("scratch/getir_page.html", "r", encoding="utf-16") as f:
    html = f.read()

# Find all text between tags that has letters
texts = re.findall(r'>([^<]+)<', html)
clean_texts = [t.strip() for t in texts if t.strip()]

print(f"Total texts found: {len(clean_texts)}")
print("Sample texts:")
for idx, text in enumerate(clean_texts[:100]):
    try:
        print(f"{idx}: {text.encode('utf-8', errors='ignore').decode('cp1254', errors='ignore')}")
    except Exception as e:
        print(f"{idx}: [encoding error] {e}")
