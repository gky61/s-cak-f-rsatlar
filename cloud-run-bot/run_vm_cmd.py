import os
import sys
import subprocess

os.environ["CLOUDSDK_PYTHON"] = sys.executable
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

cmd = sys.argv[1] if len(sys.argv) > 1 else "docker ps"
ssh_cmd = f'gcloud compute ssh telegram-bot-server --zone=us-central1-a --project=firsatkolik-prod-e6eae --quiet --command="{cmd}"'

print(f"[INFO] Running on VM: {cmd}")
r = subprocess.run(ssh_cmd, shell=True, capture_output=True, text=True, encoding='utf-8', errors='replace')
if r.stdout:
    print("STDOUT:\n", r.stdout.strip())
if r.stderr:
    print("STDERR:\n", r.stderr.strip())
