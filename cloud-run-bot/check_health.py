import os
import sys
import subprocess

os.environ["CLOUDSDK_PYTHON"] = sys.executable

env = sys.argv[1].lower() if len(sys.argv) > 1 else "dev"
port = "8081" if env == "dev" else "8082"
cmd = f'gcloud compute ssh telegram-bot-server --zone=us-central1-a --project=firsatkolik-prod-e6eae --quiet --command="curl -s http://localhost:{port}/health"'

print(f"[INFO] Checking {env.upper()} bot health on port {port}...")
r = subprocess.run(cmd, shell=True, capture_output=True, text=True)
print("STDOUT:", r.stdout.strip())
if r.stderr.strip():
    print("STDERR:", r.stderr.strip())
