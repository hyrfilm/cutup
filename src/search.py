import re
import typing
from pathlib import Path
from re import Pattern
from typing import List, Set, Union
from warnings import deprecated

from .format_util import join_items
from . import config

from . import regexp_utils
from .console import log, with_spinner

@with_spinner(style="line")
def grep(pattern: str, path: Union[str, Path]="./", **kwargs) -> List[Path]:
    file_pattern = "*"
    path_maybe = path

    if isinstance(path_maybe, str):
        # if we get a string, we treat it as a file pattern
        path = Path("./").resolve()
        file_pattern = path_maybe
    elif path_maybe.is_dir() or path_maybe.is_file():
        # if we get a dir or a file we just resolve it
        path = path_maybe.resolve()
    extensions = kwargs.get("extensions", config.get_extensions())
    ignore = kwargs.get("ignore", config.get_ignore())
    log(f"🔬📖 Searching for '{pattern}' in {path.absolute()} matching '{file_pattern}'...")
    included = f"[green]{join_items(extensions)}[/green]"
    excluded = f"[grey30]{join_items(ignore)}[/grey30]"
    log(f"+ {included}")
    log(f"- {excluded}")

    files = pattern_search(pattern, path, extensions=extensions, ignore=ignore, files=file_pattern)
    log(f"\nFound {len(files)} files.")

    if config.get_verbose():
        for i, path in enumerate(files, start=1):
            log(f"{i}. ", str(path))
    return files

@with_spinner(style="line")
def find(pattern: str, path: Union[str, Path]="./") -> List[Path]:
    path = Path(path)
    log(f"🔎📁 Finding files '{pattern}' in {path.absolute()}...")
    files = pattern_search("", path, files=pattern)
    log(f"\nFound {len(files)} files.")

    if config.get_verbose():
        for i, path in enumerate(files, start=1):
            log(f"{i}. ", str(path))
    return files


@deprecated("Use grep() or find() instead")
@with_spinner(style="line")
def search_files(pattern: str, path: Path) -> List[Path]:
    log(f"Searching for '{pattern}' in {path}...")
    files = pattern_search(
        pattern, path, extensions=config.get_extensions(), ignore=config.get_ignore()
    )
    log(f"\nFound {len(files)} files.")

    if config.get_verbose():
        for i, path in enumerate(files, start=1):
            log(f"{i}. ", str(path))
    return files


def pattern_search(
    pattern: typing.Union[str, Pattern],
    path: Path,
    extensions: Set[str] = None,
    ignore: tuple[str] = None,
    files: str = "*",
) -> List[Path]:
    """
    Search for files containing a regex pattern with filtering options.

    Args:
        path: Root directory to start search
        pattern: Regex pattern to search for
        include_extensions: Set of file extensions to include (e.g. {'.py', '.txt'})
        exclude_extensions: Set of file extensions to exclude
        exclude_dirs: Set of directory names to skip
        files: only include files matching regex pattern
    """
    matching_files = []

    if isinstance(pattern, str):
        # If the string looks like it's trying to use regex features, don't escape
        if any(c in pattern for c in "|.*+?[](){}\\"):
            pattern = re.compile(pattern)
        else:
            # Escape as literal word with boundaries
            pattern = re.compile(rf"\b{re.escape(pattern)}\b")

    def matches(f: Path, to_ignore: tuple[str]):
        for s in to_ignore:
            if s in f"{f}":
                return True
        return False

    filtered_files = []
    if not path.is_file() and not path.is_dir():
        log(f"[blink]{path}[/blink] - neither a file or directory")
    if path.is_file():
        filtered_files = [path.resolve()]
    if path.is_dir():
        filtered_files = [f for f in path.rglob(files)]

    if ignore:
        filtered_files = [f for f in filtered_files if not matches(f, ignore)]
    if extensions:
        filtered_files = [f for f in filtered_files if (f.suffix in extensions)]

    for file_path in filtered_files:
        # Skip if not a file
        if not file_path.is_file():
            continue

        # Search file content
        try:
            content = file_path.read_text()
            if pattern.search(content):
                matching_files.append(file_path)
        except (UnicodeDecodeError, IOError):
            continue

    return matching_files
