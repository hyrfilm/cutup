import contextlib
import os
from contextlib import contextmanager
from typing import Union, Iterator
from pathlib import Path
import datetime

_ENCODING = "utf-8"


def read_file(path: str) -> str:
    p = Path(path)
    if not p.exists():
        raise ValueError(f"{path} does not exist")
    if not p.is_file():
        raise ValueError(f"{path} is not a file")
    return p.read_text(_ENCODING)


def write_file(path: str, content: str) -> None:
    p = Path(path)
    p.write_text(content, encoding=_ENCODING)


def create_timestamped_dir(
    base_path: [Path, str] = "./", dir_format: str = "%Y-%m-%d %H.%M"
) -> Path:
    """
    Creates a directory inside base_path with the current timestamp as the name.

    Args: (both are optional)
        base_path (str): Either current working dir or specified path
        dir_format (str): The datetime format string (default: "2025-02-23 20.14").

    Returns:
        str: The full path of the created directory.
    """
    timestamp = datetime.datetime.now().strftime(dir_format)
    result_path = base_path.joinpath(timestamp)
    result_path.mkdir(parents=True, exist_ok=True)

    return result_path


def touch(path: Union[str, Path]) -> None:
    p = Path(path)
    p.touch(exist_ok=True)

# ── global “directory stack” ───────────────────────────────────────────
_dir_stack: list[Path] = []          # LIFO, like the shell's pushd/popd

@contextmanager
def pushd(target: Union[str, Path]) -> Iterator[None]:
    """
    Temporarily switch the process cwd to *target* and push the
    previous directory onto an internal stack.  On exit, pop and
    restore the old cwd (even if an exception occurs).
    """
    target = Path(target).expanduser().resolve()
    _dir_stack.append(Path.cwd())    # PUSH  ← current dir
    os.chdir(target)                 #        switch to new dir
    try:
        yield
    finally:
        os.chdir(_dir_stack.pop())   # POP   ← restore last dir
