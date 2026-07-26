import os
import sys
import subprocess
import tarfile
import tempfile

def run_command(command, cwd=None):
    print(f"Running: {command}")
    subprocess.check_call(command, shell=True, cwd=cwd)

try:
    # Target environment (default: dev)
    env = sys.argv[1].lower() if len(sys.argv) > 1 else "dev"
    if env not in ["dev", "prod"]:
        print("[ERROR] Invalid environment! Usage: python deploy_direct_vm.py [dev|prod]")
        sys.exit(1)

    print(f"\n[INFO] Starting DIRECT VM Docker deployment for: {env.upper()} Telegram Bot...")

    # Configuration details
    vm_name = "telegram-bot-server"
    zone = "us-central1-a"
    project_id = "firsatkolik-prod-e6eae"
    remote_dir = f"/home/murat/app/{env}-bot"
    remote_src_dir = f"/home/murat/app/{env}-src"
    container_name = f"{env}-bot"
    port = "8081" if env == "dev" else "8082"

    cloud_run_bot_dir = os.path.dirname(os.path.abspath(__file__))

    # 1. Kodları arşivle (node_modules ve .git hariç)
    tar_path = os.path.join(tempfile.gettempdir(), "bot_code.tar.gz")
    print(f"\n[INFO] Step 1: Packaging source files to {tar_path}...")
    
    with tarfile.open(tar_path, "w:gz") as tar:
        for root, dirs, files in os.walk(cloud_run_bot_dir):
            if "node_modules" in dirs:
                dirs.remove("node_modules")
            if ".git" in dirs:
                dirs.remove(".git")
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, cloud_run_bot_dir)
                tar.add(full_path, arcname=rel_path)

    # 2. Kod arşivini VM'e SCP ile yükle
    print("\n[INFO] Step 2: Uploading source code to VM via gcloud scp...")
    scp_cmd = f"gcloud compute scp {tar_path} {vm_name}:/home/murat/bot_code.tar.gz --zone={zone} --project={project_id} --quiet"
    run_command(scp_cmd)

    # 3. VM üzerinde koda çıkar, doğrudan Docker build yap ve container'ı yenile
    print("\n[INFO] Step 3: Extracting source code & building Docker image directly on VM...")
    remote_cmds = (
        f"mkdir -p {remote_src_dir} && "
        f"tar -xzf /home/murat/bot_code.tar.gz -C {remote_src_dir} && "
        f"cd {remote_src_dir} && "
        f"docker build -t telegram-bot-local:latest . && "
        f"docker stop {container_name} || true && "
        f"docker rm -f {container_name} || true && "
        f"docker run -d --name {container_name} --restart always -p {port}:8080 "
        f"--env-file {remote_dir}/.env "
        f"-v {remote_dir}/{env}_firebase_key.json:/app/firebase_key.json "
        f"telegram-bot-local:latest && "
        f"rm -f /home/murat/bot_code.tar.gz && "
        f"(docker image prune -f || true)"
    )

    ssh_cmd = f"gcloud compute ssh {vm_name} --zone={zone} --project={project_id} --quiet --command=\"{remote_cmds}\""
    run_command(ssh_cmd)

    print(f"\n[SUCCESS] DIRECT VM Docker deployment to {env.upper()} completed successfully!")

except Exception as e:
    print(f"\n[ERROR] Deployment failed: {e}")
    sys.exit(1)
