import subprocess
import os
import sys

def parse_env_yaml(path):
    env_vars = {}
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            if ':' in line:
                key, value = line.split(':', 1)
                key = key.strip()
                value = value.strip().strip('"').strip("'") # Remove quotes
                if key and value:
                    env_vars[key] = value
    return env_vars

def run_command(command, cwd=None):
    print(f"Running: {command}")
    subprocess.check_call(command, shell=True, cwd=cwd)

try:
    project_id = "sicak-firsatlar-e6eae"
    service_name = "telegram-bot"
    region = "us-central1"
    gcloud_path = "/Users/gokayalemdar/google-cloud-sdk/bin/gcloud"

    cwd = "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR/cloud-run-bot"
    
    # Read env vars
    env_path = os.path.join(cwd, 'env.yaml')
    if not os.path.exists(env_path):
        print(f"❌ Error: {env_path} not found!")
        sys.exit(1)
        
    env_vars = parse_env_yaml(env_path)
    print(f"Loaded {len(env_vars)} environment variables.")
    
    # 1. Build
    print("\n🚀 Submitting build to Cloud Build...")
    run_command(f"{gcloud_path} builds submit --config cloudbuild.yaml --project {project_id} .", cwd=cwd)

    # 2. Deploy/Update with env vars
    print("\n🚀 Updating Cloud Run service...")
    env_vars_list = [f"{k}={v}" for k, v in env_vars.items()]
    env_vars_str = ",".join(env_vars_list)
    
    cmd = (
        f"{gcloud_path} run services update {service_name} "
        f"--region {region} "
        f"--project {project_id} "
        f"--set-env-vars \"{env_vars_str}\""
    )
    run_command(cmd, cwd=cwd)

    print("\n✅ Deployment completed successfully!")

except Exception as e:
    print(f"\n❌ Error during deployment: {e}")
    sys.exit(1)
