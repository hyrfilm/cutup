import os
import typer
from pathlib import Path
from typing import Annotated

from .env_vars import ENV_PREFIX
from . import agent_tools
from .env_vars import ensure_env_vars, get_env_var, print_env_vars, CWD, REPO

# script path & repo root are always available as env vars
REPO_ENV_VAR = f"${ENV_PREFIX}_{REPO}"
CWD_ENV_VAR = f"${ENV_PREFIX}_{CWD}"


def main(
    script: Annotated[Path, typer.Argument(envvar=CWD_ENV_VAR)],
    repo_root: Annotated[Path, typer.Argument(envvar=REPO_ENV_VAR)] = "./",
):
    # Check for environment variables
    cwd_env = os.getenv(CWD)
    repo_env = os.getenv(REPO)

    ensure_env_vars([(CWD, str(script)), (REPO, str(repo_root))])
    print_env_vars()

    # Use environment variables if set
    script = Path(cwd_env) if cwd_env else script
    repo_root = Path(repo_env) if repo_env else repo_root

    # Initialize agent tools
    agent_tools.initialize()

    # Execute the script
    exec(script.read_text("utf-8"), globals=globals(), locals=locals())


if __name__ == "__main__":
    typer.run(main)
