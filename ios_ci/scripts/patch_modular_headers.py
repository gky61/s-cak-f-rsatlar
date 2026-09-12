#!/usr/bin/env python3
"""
FırsatKolik iOS CI/CD - FlutterFire Xcode 16 Modular Header Patcher

Xcode 16 Clang enforces strict modularity for framework modules.
Older FlutterFire versions import <Firebase/Firebase.h> directly in header files,
triggering: "Lexical or Preprocessor Issue (Xcode): Include of non-modular header inside framework module".

This script automatically patches those imports in ~/.pub-cache/hosted/pub.dev (or Windows equivalent)
matching the official FlutterFire PR #13400 (commit d7d2d4b93e7c00226027fffde46699f3d5388a41).
"""

import glob
import os
import re
import sys

def find_pub_cache_dirs():
    dirs = []
    # Environment variables
    if os.environ.get("PUB_CACHE"):
        dirs.append(os.path.join(os.environ["PUB_CACHE"], "hosted", "pub.dev"))
    
    # macOS / Linux standard
    home = os.path.expanduser("~")
    dirs.append(os.path.join(home, ".pub-cache", "hosted", "pub.dev"))
    
    # Windows standard
    local_app_data = os.environ.get("LOCALAPPDATA")
    if local_app_data:
        dirs.append(os.path.join(local_app_data, "Pub", "Cache", "hosted", "pub.dev"))
    
    existing = [d for d in dirs if os.path.isdir(d)]
    return list(dict.fromkeys(existing))

def patch_file(filepath, replacements):
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
        
        modified = False
        new_content = content
        for pattern, repl in replacements:
            if isinstance(pattern, str):
                if pattern in new_content:
                    new_content = new_content.replace(pattern, repl)
                    modified = True
            elif hasattr(pattern, "sub"):
                sub_res, count = pattern.subn(repl, new_content)
                if count > 0:
                    new_content = sub_res
                    modified = True
        
        if modified:
            with open(filepath, "w", encoding="utf-8", newline="\n") as f:
                f.write(new_content)
            print(f"   [+] Patched: {os.path.basename(filepath)} ({filepath})")
            return True
    except Exception as e:
        print(f"   [!] Could not patch {filepath}: {e}")
    return False

def main():
    print("[Patch] Checking FlutterFire packages in pub-cache for Xcode 16 modular header compatibility...")
    cache_dirs = find_pub_cache_dirs()
    if not cache_dirs:
        print("   [!] No pub-cache directory found. Skipping header patch.")
        return 0

    total_patched = 0

    for cache_dir in cache_dirs:
        print(f"   Scanning pub-cache at: {cache_dir}")
        
        # 1. firebase_app_check
        for p in glob.glob(os.path.join(cache_dir, "firebase_app_check-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            fname = os.path.basename(p)
            if fname == "FLTAppCheckProvider.h":
                if patch_file(p, [
                    ("#import <Firebase/Firebase.h>\n#import <FirebaseAppCheck/FIRAppCheck.h>", "@import FirebaseAppCheck;"),
                    ("#import <Firebase/Firebase.h>", "@import FirebaseAppCheck;")
                ]): total_patched += 1
            elif fname in ["FLTAppCheckProviderFactory.m", "FLTFirebaseAppCheckPlugin.m"]:
                if patch_file(p, [
                    ("#import <Firebase/Firebase.h>", "@import FirebaseAppCheck;\n@import FirebaseCore;")
                ]): total_patched += 1

        # 2. firebase_messaging
        for p in glob.glob(os.path.join(cache_dir, "firebase_messaging-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebaseMessaging;")
            ]): total_patched += 1

        # 3. firebase_crashlytics
        for p in glob.glob(os.path.join(cache_dir, "firebase_crashlytics-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebaseCrashlytics;")
            ]): total_patched += 1

        # 4. firebase_performance
        for p in glob.glob(os.path.join(cache_dir, "firebase_performance-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebasePerformance;")
            ]): total_patched += 1

        # 5. firebase_auth
        for p in glob.glob(os.path.join(cache_dir, "firebase_auth-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebaseAuth;")
            ]): total_patched += 1

        # 6. firebase_storage
        for p in glob.glob(os.path.join(cache_dir, "firebase_storage-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebaseStorage;")
            ]): total_patched += 1

        # 7. cloud_firestore
        for p in glob.glob(os.path.join(cache_dir, "cloud_firestore-*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebaseFirestore;\n@import FirebaseCore;")
            ]): total_patched += 1

        # 8. Fallback for any other firebase_* package headers importing <Firebase/Firebase.h>
        for p in glob.glob(os.path.join(cache_dir, "firebase_*", "ios", "Classes", "**", "*.[hm]"), recursive=True):
            if patch_file(p, [
                ("#import <Firebase/Firebase.h>", "@import FirebaseCore;")
            ]): total_patched += 1

    print(f"[Patch] Finished. Total files patched: {total_patched}")
    return 0

if __name__ == "__main__":
    sys.exit(main())

