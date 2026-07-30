import os
import sys
import subprocess

def run_command(command, cwd=None):
    print(f"Running: {command}")
    subprocess.check_call(command, shell=True, cwd=cwd)

try:
    # Get target environment (default is dev)
    env = sys.argv[1].lower() if len(sys.argv) > 1 else "dev"
    if env not in ["dev", "prod"]:
        print("[ERROR] Invalid environment! Usage: python deploy_to_vm.py [dev|prod]")
        sys.exit(1)

    print(f"\n[INFO] Starting Docker-based deployment for: {env.upper()} Telegram Bot to VM...")

    # Configuration details
    vm_name = "telegram-bot-server"
    zone = "us-central1-a"
    project_id = "firsatkolik-prod-e6eae"  # VM and GCR reside in PROD project
    service_name = "telegram-bot"
    remote_dir = f"/home/murat/app/{env}-bot"
    container_name = f"{env}-bot"
    port = "8081" if env == "dev" else "8082"

    # Current working directory (cloud-run-bot directory)
    cwd = os.path.dirname(os.path.abspath(__file__))

    # 1. Submit build to Cloud Build (builds Docker container in the cloud)
    print("\n[INFO] Step 1: Submitting build to Google Cloud Build...")
    build_cmd = f"gcloud builds submit --tag gcr.io/{project_id}/{service_name}:latest --project {project_id} ."
    run_command(build_cmd, cwd=cwd)

    # 2. Deploy to VM as a Docker container
    print("\n[INFO] Step 2: Running deployment commands on VM via SSH...")
    
    # We pull the latest image, stop/rm any old container, run the new container,
    # mounting the local key JSON as /app/firebase_key.json, and loading the .env file.
    # Finally, we prune old images to keep disk space usage at 0 (without failing if prune conflicts).
    docker_run_cmd = (
        f"docker pull gcr.io/{project_id}/{service_name}:latest && "
        f"docker stop {container_name} || true && "
        f"docker rm -f {container_name} || true && "
        f"docker run -d --name {container_name} --restart always -p {port}:8080 "
        f"--env-file {remote_dir}/.env "
        f"-v {remote_dir}/{env}_firebase_key.json:/app/firebase_key.json "
        f"gcr.io/{project_id}/{service_name}:latest && "
        f"(docker image prune -a -f || true)"
    )

    ssh_cmd = f"gcloud compute ssh {vm_name} --zone={zone} --project={project_id} --quiet --command=\"{docker_run_cmd}\""
    run_command(ssh_cmd, cwd=cwd)

    print(f"\n[SUCCESS] Docker-based deployment to {env.upper()} VM completed successfully!")

except Exception as e:
    print(f"\n[ERROR] Deployment failed: {e}")
    sys.exit(1)
