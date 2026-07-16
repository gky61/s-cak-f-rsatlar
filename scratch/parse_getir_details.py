import json

with open("scratch/getir_parsed.json", "r", encoding="utf-8") as f:
    data = json.load(f)

initialState = data.get("props", {}).get("pageProps", {}).get("initialState", {})
p_detail = initialState.get("productDetail", {})
p_data = p_detail.get("data", {})

print("PRODUCT DETAIL DATA:")
print("Name:", p_data.get("name"))
print("Price:", p_data.get("price"))
print("Struck Price (Original Price):", p_data.get("struckPrice"))
print("Short Description:", p_data.get("shortDescription"))
print("Details (Full description?):", p_data.get("details"))

getirListing = initialState.get("getirListing", {})
print("\nGETIR LISTING CATEGORIES:")
categories = getirListing.get("categories", [])
print("Categories type:", type(categories))

if isinstance(categories, list):
    print("Categories is a list of length:", len(categories))
    for cat in categories[:5]:
        print("Cat:", cat)
elif isinstance(categories, dict):
    print("Categories is a dict with keys:", list(categories.keys()))
    # Let's inspect the values or check if there is list of categories in value
    for key, val in categories.items():
        print(f"Key: {key}, Val type: {type(val)}")
        if isinstance(val, list):
            print(f"Val list length: {len(val)}")
            if len(val) > 0:
                print(f"First item: {val[0]}")
