import json
import re

with open("scratch/getir_page.html", "r", encoding="utf-16") as f:
    html = f.read()

# Match the content of the script tag
match = re.search(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', html, re.DOTALL)
if match:
    data = json.loads(match.group(1))
    with open("scratch/getir_parsed.json", "w", encoding="utf-8") as out:
        json.dump(data, out, indent=2, ensure_ascii=False)
    
    print("SUCCESS: __NEXT_DATA__ JSON parsed and written to scratch/getir_parsed.json")
    
    # Traverse structure
    props = data.get("props", {})
    pageProps = props.get("pageProps", {})
    print("pageProps keys:", list(pageProps.keys()))
    
    # Check what else is inside pageProps
    for key in list(pageProps.keys()):
        val = pageProps[key]
        if isinstance(val, dict):
            print(f"pageProps.{key} keys: {list(val.keys())}")
        else:
            print(f"pageProps.{key} type: {type(val)}")
            
    initialState = pageProps.get("initialState", {}) or props.get("initialState", {})
    if initialState:
        print("initialState keys:", list(initialState.keys()))
        for key in ["productDetail", "getirListing", "localsProductDetail", "restaurantDetail"]:
            if key in initialState:
                val = initialState[key]
                if isinstance(val, dict):
                    print(f"initialState.{key} keys: {list(val.keys())}")
                    # Print preview of 'data' or similar if present
                    if "data" in val:
                        d_val = val["data"]
                        if isinstance(d_val, dict):
                            print(f"initialState.{key}.data keys: {list(d_val.keys())}")
                        else:
                            print(f"initialState.{key}.data type: {type(d_val)}")
                            if isinstance(d_val, list) and len(d_val) > 0:
                                print(f"initialState.{key}.data[0] type: {type(d_val[0])}")
                                if isinstance(d_val[0], dict):
                                    print(f"initialState.{key}.data[0] keys: {list(d_val[0].keys())}")
else:
    print("ERROR: __NEXT_DATA__ script tag not found")
