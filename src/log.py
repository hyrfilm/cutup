import time
import typing
from queue import Queue
from threading import Thread

from rich import print as rprint
from rich.live import Live
from rich.spinner import Spinner
from rich._spinners import SPINNERS


def rlog(*s: str):
    rprint(*s)


from functools import wraps
from rich.spinner import Spinner
from rich.live import Live
from rich.console import Console


def with_spinner(style: str, message: str=""):
    """Decorator that shows a spinner animation while a function executes.

    Args:
        message (str): Message to show next to the spinner
    """

    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            console = Console()
            with console.status(message, spinner=style, speed=2.0, refresh_per_second=24) as status:
                result = func(*args, **kwargs)
            return result

        return wrapper

    return decorator
