import re

with open("scratch/getir_page.html", "r", encoding="utf-16") as f:
    html = f.read()

def print_safe(text):
    try:
        print(text.encode('utf-8', errors='ignore').decode('cp1254', errors='ignore'))
    except:
        pass

# Find all meta tags
meta_tags = re.findall(r'<meta[^>]+>', html)
for meta in meta_tags:
    print_safe(meta)
