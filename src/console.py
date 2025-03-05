from functools import wraps
from rich.console import Console
from rich._spinners import SPINNERS
from rich import print as rprint
from rich.padding import Padding

# Global spinner tracking
_spinner_keys = list(SPINNERS.keys())
_spinner_index = 0  # Tracks the current spinner index


def log(*s: str):
    rprint(*s)


def indented_log(message: str):
    log(Padding(message, pad=(0, 0, 0, 16)))


def _spinner_decorator(get_spinner, message: str, speed: float, refresh_rate: int):
    """Helper function to create a spinner decorator."""

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            spinner_name = get_spinner()
            console = Console()

            with console.status(
                message,
                spinner=spinner_name,
                speed=speed,
                refresh_per_second=refresh_rate,
            ):
                return func(*args, **kwargs)

        return wrapper

    return decorator


def with_spinner(style: str, message: str = "", speed=2.0, refresh_rate=24, indent=0):
    """Static spinner decorator (fixed style)."""
    return _spinner_decorator(lambda: style, message, speed, refresh_rate)


def with_cycling_spinner(
    initial_spinner: str, message: str = "", speed=2.0, refresh_rate=24, indent=0
):
    """Cycling spinner decorator that moves to the next available spinner each call."""
    global _spinner_index

    if initial_spinner not in _spinner_keys:
        raise ValueError(
            f"Invalid spinner name '{initial_spinner}'. Available spinners: {', '.join(_spinner_keys)}"
        )

    _spinner_index = _spinner_keys.index(initial_spinner)  # Set starting position

    def get_next_spinner():
        global _spinner_index
        spinner = _spinner_keys[_spinner_index]
        _spinner_index = (_spinner_index + 1) % len(_spinner_keys)  # Cycle to next
        return spinner

    return _spinner_decorator(get_next_spinner, message, speed, refresh_rate)
