from pathlib import Path, PurePath
from typing import Tuple
import re
from . import env_vars

PATH_PREFIX = "path://"
PATH_SEPARATOR = "/"  # we're not using os.sep since it varies between platforms
VAR_PREFIX = "$"
START_VAR = "{"
END_VAR = "}"
VAR_REGEXP = re.compile(START_VAR + "(.+)" + END_VAR)


class UnresolvedPathError(Exception):
    pass


def consume(s: str) -> Tuple[bool, str, str]:
    """Tries to consume a part of the string.
    Returns a tuple of (bool, str, str) where the
    1) boolean indicates if the consumption was successful,
    2) the part of the string that was consumed (if a variable was consumed this will be the variable name)
    3) the remaining string.
    """
    if s.startswith(PATH_PREFIX):
        s = s.removeprefix(PATH_PREFIX)
        return True, PATH_PREFIX, s
    if s.startswith(VAR_PREFIX):
        s = s.removeprefix(VAR_PREFIX)
        if VAR_REGEXP.match(s):
            complete_match = VAR_REGEXP.match(s).group(0)
            var_name = VAR_REGEXP.match(s).group(1)
            s = s.removeprefix(complete_match)
            return True, var_name.strip(), s
    return False, "", s


def is_ref(s: str) -> bool:
    """Returns True if the string is a path_ref that needs to be resolved otherwise False."""
    return PATH_PREFIX in s


def resolve_path_ref(s: str) -> str:
    if not is_ref(s):
        return s

    path_ref = s
    # Handle path://
    match, matched_str, s = consume(s)
    if not match:
        raise UnresolvedPathError(f"Missing path protocol: {PATH_PREFIX} in {s}")

    cwd = env_vars.get_env_var(env_vars.CWD)
    # Handle ${env_var} (for overriding cwd - which is the default)
    match, var_name, remaining = consume(s)
    if match:
        var_value = env_vars.get_env_var(var_name)
        if not var_value:
            raise UnresolvedPathError(
                f"Variable '{var_name}' not found in environment variables"
            )
        else:
            cwd = var_value

    if remaining.startswith(PATH_SEPARATOR):
        remaining = remaining.removeprefix(PATH_SEPARATOR)

    fullpath = f"{cwd} + {remaining}"
    # Build path, make it absolute
    try:
        fullpath = Path(cwd) / Path(remaining)
        resolved_path = fullpath.resolve(strict=True)
    except OSError as e:
        raise UnresolvedPathError(
            f"Failed to resolve '{path_ref}' into {fullpath}: {e}"
        ) from e

    return str(resolved_path)


def resolve(s: str) -> str:
    """Given a string, looks for any path protocol,
    and resolves every path protocol, eg path:// into an absolute path and
    return the string."""
    resolved_parts = [resolve_path_ref(part) for part in s.split(" ")]
    return " ".join(resolved_parts)
