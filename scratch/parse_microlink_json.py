import json

# The file might be in UTF-16 due to PowerShell redirect, let's try UTF-16 first, then UTF-8
try:
    with open("scratch/getir_microlink.json", "r", encoding="utf-16") as f:
        content = f.read()
except Exception:
    with open("scratch/getir_microlink.json", "r", encoding="utf-8") as f:
        content = f.read()

# If empty or not valid json
try:
    data = json.loads(content)
    print("SUCCESS: Valid JSON received from Microlink.")
    print("Keys:", list(data.keys()))
    if "status" in data:
        print("Status:", data["status"])
    if "data" in data and "html" in data["data"]:
        html = data["data"]["html"]
        print("HTML length:", len(html))
        # Check if the HTML contains product name or request blocked
        if "Chunkies" in html:
            print("FOUND: 'Chunkies' in HTML!")
        if "request could not be satisfied" in html.lower():
            print("BLOCKED: CloudFront block is present in HTML!")
    else:
        print("NO HTML inside data:", data.get("data", {}).keys())
except Exception as e:
    print("ERROR parsing JSON:", e)
    print("Content preview:", content[:500])
