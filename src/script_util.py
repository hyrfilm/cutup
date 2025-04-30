import importlib
import os
import runpy
import sys
from pathlib import Path

from . import config
from .env_vars import get_env_var, set_env_var
from .env_vars import CWD, PROJECT


def run_script(script: Path):
    abs_script_path = Path(os.getcwd()) / Path(script)
    abs_script_path.parent.resolve(strict=True)
    if abs_script_path.is_file():
        script_dir = abs_script_path.parent
        set_env_var(CWD, str(script_dir))
        set_env_var(PROJECT, str(get_env_var(PROJECT, config.get_project_dir())))
        os.chdir(script_dir)

    runpy.run_path(str(script.name))

    # abs_script_path = Path(os.getcwd()) / Path(script)
    # abs_script_path.parent.resolve(strict=True)
    # if abs_script_path.is_file():
    #     script_dir = abs_script_path.parent
    #     set_env_var(CWD, str(script_dir))
    #     set_env_var(PROJECT, str(get_env_var(PROJECT, config.get_project_dir())))
    #     os.chdir(script_dir)
    #
    # exec(abs_script_path.read_text("utf-8"), globals=globals(), locals=locals())
