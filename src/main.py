import typer
from pathlib import Path
from typing import Annotated

from .env_vars import ENV_PREFIX, CWD, REPO
from .agent_tools import create_agent
from .script_util import run_script

# script path & repo root are always available as env vars
REPO_ENV_VAR = f"${ENV_PREFIX}_{REPO}"
CWD_ENV_VAR = f"${ENV_PREFIX}_{CWD}"


def main(
    script: Annotated[Path, typer.Argument(envvar=CWD_ENV_VAR)],
    repo_root: Annotated[Path, typer.Argument(envvar=REPO_ENV_VAR)] = "./",
):
    create_agent()
    run_script(script)


if __name__ == "__main__":
    typer.run(main)
