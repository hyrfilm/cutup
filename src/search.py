import typing
from pathlib import Path
from re import Pattern
from typing import List, Set
from . import config

from . import regexp_utils
from .log import rlog, spinner


def search_files(pattern: str, path: Path, verbose: bool) -> List[Path]:
    rlog(f"Searching for '{pattern}' in {path}...")
    stop_spinner = spinner()
    files = pattern_search(
        pattern, path, extensions=config.extensions, ignore=config.ignore
    )
    stop_spinner()
    rlog(f"Found {len(files)} files.")

    if verbose:
        for i, path in enumerate(files, start=1):
            rlog(f"{i}. ", str(path))
    return files


def pattern_search(
    pattern: typing.Union[str, Pattern],
    path: Path,
    extensions: Set[str] = None,
    ignore: tuple[str] = None,
) -> List[Path]:
    """
    Search for files containing a regex pattern with filtering options.

    Args:
        path: Root directory to start search
        pattern: Regex pattern to search for
        include_extensions: Set of file extensions to include (e.g. {'.py', '.txt'})
        exclude_extensions: Set of file extensions to exclude
        exclude_dirs: Set of directory names to skip
    """
    matching_files = []

    if isinstance(pattern, str):
        pattern = regexp_utils.compile(pattern)

    def matches(f: Path, to_ignore: tuple[str]):
        for s in to_ignore:
            if s in f"{f}":
                return True
        return False

    filtered_files = [f for f in path.rglob("*") if not matches(f, ignore)]
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
