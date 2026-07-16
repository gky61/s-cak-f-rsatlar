import subprocess

def run_remote_script(js_code):
    # We write the js_code to a file using cat with EOF, then run node on it
    wrapped_command = f"cat << 'EOF' > /tmp/getir_test.js\n{js_code}\nEOF\nnode /tmp/getir_test.js"
    
    ssh_cmd = [
        "gcloud.cmd", "compute", "ssh", "telegram-bot-server",
        "--zone=us-central1-a",
        "--command=" + wrapped_command,
        "--quiet"
    ]
    result = subprocess.run(ssh_cmd, capture_output=True, text=True, shell=False)
    print("STDOUT:")
    print(result.stdout)
    print("STDERR:")
    print(result.stderr)
    print("Exit Code:", result.returncode)

js_code = """
async function main() {
  try {
    const res = await fetch('https://getir.com/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/');
    console.log('Direct Getir Status:', res.status);
    const html = await res.text();
    console.log('Direct HTML length:', html.length);
  } catch (e) {
    console.error('Direct Getir Error:', e.message);
  }

  try {
    const res = await fetch('https://getir-com.translate.goog/urun/chunkies-magnum-badem-nogger-paketi-mkbemgrdz5/?_x_tr_sl=auto&_x_tr_tl=tr');
    console.log('Translate Getir Status:', res.status);
    const html = await res.text();
    console.log('Translate HTML length:', html.length);
  } catch (e) {
    console.error('Translate Getir Error:', e.message);
  }
}
main();
"""

run_remote_script(js_code)
