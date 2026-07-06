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
    # Get project_id dynamically from command line argument, fallback to prod project ID
    project_id = sys.argv[1] if len(sys.argv) > 1 else "firsatkolik-prod-e6eae"
    service_name = "telegram-bot"
    region = "us-central1"

    # Determine cwd dynamically based on script file location
    cwd = os.path.dirname(os.path.abspath(__file__))
    
    # Read env vars
    env_path = os.path.join(cwd, 'env.yaml')
    env_vars = {}
    if os.path.exists(env_path):
        env_vars = parse_env_yaml(env_path)
        print(f"Loaded {len(env_vars)} environment variables from env.yaml.")
    else:
        print(f"⚠️ Warning: {env_path} not found! Continuing with secrets and arguments.")

    # 1. Build using Cloud Build
    print("\n[INFO] Submitting build to Cloud Build...")
    # Using 'gcloud' from system path
    run_command(f"gcloud builds submit --tag gcr.io/{project_id}/{service_name}:latest --project {project_id} .", cwd=cwd)

    # 2. Deploy container to Cloud Run
    print("\n[INFO] Deploying Cloud Run service...")
    
    # Filter out secrets from env vars if they are in env.yaml to prevent plain text exposure
    filtered_env = {k: v for k, v in env_vars.items() if k not in ['GEMINI_API_KEY', 'TELEGRAM_SESSION_STRING', 'TELEGRAM_STRING_SESSION']}
    # Add PROJECT_ID environment variable
    filtered_env['PROJECT_ID'] = project_id
    
    # Write temporary YAML file for deployment
    temp_env_path = os.path.join(cwd, 'env_deploy.yaml')
    with open(temp_env_path, 'w') as f:
        for k, v in filtered_env.items():
            f.write(f"{k}: \"{v}\"\n")
            
    # Secrets bindings configuration
    secrets_str = "GEMINI_API_KEY=GEMINI_API_KEY:latest,TELEGRAM_SESSION_STRING=TELEGRAM_STRING_SESSION:latest"
    
    cmd = (
        f"gcloud run deploy {service_name} "
        f"--image gcr.io/{project_id}/{service_name}:latest "
        f"--region {region} "
        f"--project {project_id} "
        f"--platform managed "
        f"--no-cpu-throttling "
        f"--min-instances 1 "
        f"--max-instances 1 "
        f"--memory 512Mi "
        f"--allow-unauthenticated "
    )
    
    if filtered_env:
        cmd += f"--env-vars-file=\"{temp_env_path}\" "
        
    cmd += f"--set-secrets \"{secrets_str}\""
    
    try:
        run_command(cmd, cwd=cwd)
    finally:
        # Clean up temporary file
        if os.path.exists(temp_env_path):
            os.remove(temp_env_path)


    print("\n[SUCCESS] Deployment completed successfully!")

except Exception as e:
    print(f"\n[ERROR] Error during deployment: {e}")
    sys.exit(1)

