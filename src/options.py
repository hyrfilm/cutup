import os
from pathlib import Path


def save_output() -> bool:
    return os.environ.get("SAVE_OUTPUT") == "False"


def get_repo_root() -> Path:
    return Path(os.environ.get("REPO_ROOT"))
