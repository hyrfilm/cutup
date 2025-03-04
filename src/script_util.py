import os
from pathlib import Path

from .env_vars import set_env_var, CWD


def run_script(script: Path):
    abs_script_path = Path(os.getcwd()) / Path(script)
    abs_script_path.parent.resolve(strict=True)
    if abs_script_path.is_file():
        script_dir = abs_script_path.parent
        set_env_var(CWD, str(script_dir))
        os.chdir(script_dir)

    exec(abs_script_path.read_text("utf-8"), globals=globals(), locals=locals())
