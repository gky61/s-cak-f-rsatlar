#!/usr/bin/env python3
"""
FırsatKolik GCP VM (telegram-bot-server) Manuel Temizlik Scripti
Kullanım: python cloud-run-bot/clean_vm.py
"""

import subprocess
import sys
import io

# Force UTF-8 stdout encoding for Windows compatibility
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

VM_NAME = "telegram-bot-server"
ZONE = "us-central1-a"
PROJECT_ID = "firsatkolik-prod-e6eae"

def run_remote_clean():
    print(f"[VM-CLEAN] Connecting to VM ({VM_NAME}) in project {PROJECT_ID}...")
    
    ssh_cmd = f'gcloud compute ssh {VM_NAME} --zone={ZONE} --project={PROJECT_ID} --command="~/clean_vm.sh"'

    try:
        res = subprocess.run(ssh_cmd, shell=True, check=True)
        if res.returncode == 0:
            print("\n[VM-CLEAN] ✅ VM Temizleme İşlemi Başarıyla Tamamlandı!")
    except subprocess.CalledProcessError as e:
        print(f"\n[VM-CLEAN] ❌ Hata Oluştu: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_remote_clean()
