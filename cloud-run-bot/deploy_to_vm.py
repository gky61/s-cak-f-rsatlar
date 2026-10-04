import os
import sys
import subprocess

# Ensure gcloud uses current Python interpreter on Windows
os.environ["CLOUDSDK_PYTHON"] = sys.executable

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

    # P1-02 (R-INF-09): Değişmez (Immutable) Git-SHA etiketleme mimarisi
    try:
        commit_sha = subprocess.check_output(["git", "rev-parse", "--short", "HEAD"], cwd=cwd).decode().strip()
    except Exception:
        commit_sha = "manual"

    image_tag = f"gcr.io/{project_id}/{service_name}:{env}-{commit_sha}"
    print(f"[INFO] Hedef Docker İmajı: {image_tag}")

    # Check if build step should be skipped
    skip_build = "--skip-build" in sys.argv

    # 1. Submit build to Cloud Build (builds Docker container in the cloud with Git-SHA)
    if not skip_build:
        print(f"\n[INFO] Step 1: Submitting build to Google Cloud Build ({image_tag})...")
        build_cmd = f"gcloud builds submit --tag {image_tag} --project {project_id} ."
        run_command(build_cmd, cwd=cwd)
    else:
        print(f"\n[INFO] Step 1: Skipping Cloud Build (--skip-build specified, reusing {image_tag})...")

    # 2. Deploy to VM as a Docker container
    print("\n[INFO] Step 2: Running deployment commands on VM via SSH...")
    
    # P1-02 & P1-03: Değişmez Git-SHA imajı çek, fail-closed PROJECT_ID enjekte et, güvenli dangling prune yap
    # docker image prune -f: Yalnızca etiketsiz katmanları siler, önceki SHA imajlarını diskte tutarak 5 sn rollback sağlar.
    # P1-26 (R-INF-04): e2-micro (1GB RAM) OOM kalkanı - Docker cgroup kaynak sınırları
    memory_limit = "--memory=500m --memory-swap=500m --cpus=0.70" if env == "prod" else "--memory=250m --memory-swap=250m --cpus=0.25"

    docker_run_cmd = (
        f"docker pull {image_tag} && "
        f"docker rm -f {container_name} || true && "
        f"docker run -d --name {container_name} --restart always -p {port}:8080 "
        f"{memory_limit} "
        f"-e PROJECT_ID={project_id} -e NODE_ENV={env} "
        f"--env-file {remote_dir}/.env "
        f"-v {remote_dir}/{env}_firebase_key.json:/app/firebase_key.json "
        f"{image_tag} && "
        f"(docker image prune -f || true)"
    )

    ssh_cmd = f"gcloud compute ssh {vm_name} --zone={zone} --project={project_id} --quiet --command=\"{docker_run_cmd}\""
    run_command(ssh_cmd, cwd=cwd)

    print(f"\n[SUCCESS] Docker-based deployment to {env.upper()} VM completed successfully!")

except Exception as e:
    print(f"\n[ERROR] Deployment failed: {e}")
    sys.exit(1)
