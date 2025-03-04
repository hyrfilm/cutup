import os
from pathlib import Path
from .env_vars import get_env_var


def save_output() -> bool:
    return get_env_var("SAVE_OUTPUT", "False") == "True"


def get_repo_root() -> Path:
    return Path(os.environ.get("REPO"))
