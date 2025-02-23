
import typer

from pathlib import Path
from typing import Annotated

from . import regexp_utils, config
from .log import rlog
from .openai import get_chat_completion
from .search import search_files


def main(
    pattern: Annotated[str, typer.Argument(...)],
    path: Annotated[
        Path,
        typer.Option("--path", "-p"),
    ] = Path("."),
    verbose: Annotated[bool, typer.Option("--verbose", "-v")] = False,
    ignore_case: Annotated[bool, typer.Option("--case-insesitive", "-i")] = False,
):
    if ignore_case:
        regexp_utils.ignore_casing()
    if verbose:
        config.set_verbose(True)

    files = search_files(pattern, path, verbose)
    for file in files:
        if config.write_reference:
            content = file.read_text()
            reference = Path(f"./{file.stem}{file.suffix}")
            rlog(f"Writing original {file} -> {reference} as reference")
            reference.write_text(content)

        rlog(f"[orange]Sending[/orange] '{file}' to {config.model}...")
        results = get_chat_completion(file.read_text("utf-8"))

        for result in results:
            write_result(result, file)

        return


def write_result(completion, file):
    code, text, name = completion
    filename = Path(file.stem + f"_{name}.js")
    if code:
        rlog(f"[green]Writing[/green] '{file}' to '{file.name}' :sparkles:...")
        filename.write_text(code, encoding="utf-8")
    if text:
        rlog("[blink]Annotation:[/blink]")
        rlog(text)
