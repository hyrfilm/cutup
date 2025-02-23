from typing import Union

from pydantic_ai import Agent

from src.io import SourceFile
from src import io

agent = Agent()


@agent.tool_plain
def readfile(path: str):
    """
    Reads the content of a file and returns a SourceFile object.

    Args:
        path (str): The path to the file.

    Returns:
        SourceFile: An object containing the file path and content.

    Raises:
        ValueError: If the path does not exist or is not a file.
    """
    return io.read_file(path)


@agent.tool_plain()
def writefile(path: str, content: str) -> SourceFile:
    """
    Writes content to a file and returns a SourceFile object. Accepts either a path and content or a SourceFile object.

    Args:
        path (path: str The file path to write to.
        content (str: str): The content to write if a path is provided.

    Returns:
        SourceFile: An object containing the file path and content.

    Raises:
        ValueError: If neither content nor SourceFile content is provided.
    """
    return io.write_file(path, content)
