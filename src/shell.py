import subprocess

def shell(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if result.returncode == 0:
        return result.stdout
    else:
        raise RuntimeError(f"Command failed\\n{result.stderr}")
