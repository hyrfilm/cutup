import typer
from pathlib import Path
from typing import Annotated
from . import config
from . import agent_tools


def main(
    script: Annotated[Path, typer.Argument(...)],
    repo_root: Annotated[Path, typer.Argument(...)],
):
    config.set_repo_dir(repo_root)
    config.set_cwd_dir(script.parent)

    agent_tools.initialize()

    exec(script.read_text("utf-8"), globals=globals(), locals=locals())


if __name__ == "__main__":
    typer.run(main)
