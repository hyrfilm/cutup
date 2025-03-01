# these can actually be used interchangebly
# path:// is the "offically" recommended one,
# file:// for being tolerant with faulty input
from os import getcwd
from pathlib import Path

from src import options

PATH_PREFIX = "path://"
FILE_PREFIX = "file://"

# we resolve these lazily so we know the most updated values are there
path_variables = {
    "cwd": lambda: Path(getcwd()),
    "repo": lambda: Path(getcwd()) / Path(options.get_repo_root()),
}

# these mean the same thing
PATH_PROTOCOLS = {PATH_PREFIX, FILE_PREFIX}


def is_path_ref(s: str):
    for prefix in PATH_PROTOCOLS:
        if s.startswith(prefix):
            return True
    return False


def _resolve_part(s: str) -> str:
    part_fun = path_variables.get(s, lambda: s)
    return part_fun()


def _resolve_path_refs(s: str) -> str:
    if not is_path_ref(s):
        return s
    else:
        s = s.removeprefix(PATH_PREFIX)
        s = s.removeprefix(FILE_PREFIX)
        path_segments = Path(s).parts
        all_parts = [Path(part) for part in path_segments]
        absolute_path = Path.joinpath(*all_parts).resolve(strict=True)
        return str(absolute_path)


def resolve(s: str) -> str:
    """Given a string, looks for any path protocol,
    and resolves every path protocol, eg path:// into an absolute path and
    return the string."""
    resolved_parts = [_resolve_path_refs(part) for part in s.split(" ")]
    return " ".join(resolved_parts)
