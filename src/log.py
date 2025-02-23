import asyncio
import time
import typing
from threading import Thread

from rich import print as rprint
from rich.live import Live
from rich.spinner import Spinner
from rich.status import Status


def rlog(*s: str):
    rprint(*s)


def spinner(style: str = "line", msg="") -> typing.Callable[[], None]:
    spinner = SpinnerAnimation(msg, style)
    spinner.start()
    return spinner.stop


class SpinnerAnimation:
    def __init__(self, message: str, style: str = "line", speed=2.0):
        self.spinner = Spinner(style, message, speed=speed)
        self.live = Live(self.spinner, refresh_per_second=20, transient=True)
        self._running = False
        self._thread = None

    def start(self):
        self._running = True
        self._thread = Thread(target=self._animate, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join()

    def _animate(self):
        with self.live:
            while self._running:
                time.sleep(0.1)
                self.spinner.update()
