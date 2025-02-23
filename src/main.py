import os

import typer
from pathlib import Path
from typing import Annotated

from rich.live import Live

repo = None
cwd = None

def main(script: Annotated[Path, typer.Argument(...)], repo_root: Annotated[Path, typer.Argument(...)]):
    global repo, cwd
    repo = repo_root
    cwd = script.parent
    exec(script.read_text("utf-8"), globals=globals(), locals=locals())


if __name__ == "__main__":
    typer.run(main)
