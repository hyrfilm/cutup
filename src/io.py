from typing import Union
from pathlib import Path
import datetime

from openai import BaseModel

_ENCODING = "utf-8"


class SourceFile(BaseModel):
    """
    Represents a source file with its path and content.

    Attributes:
        path (str): The file path.
        content (str): The content of the file.
    """

    path: str
    content: str


def read_file(path: str):
    p = Path(path)
    if not p.exists():
        raise ValueError(f"{path} does not exist")
    if not p.is_file():
        raise ValueError(f"{path} is not a file")
    s = p.read_text(_ENCODING)
    return SourceFile(path=str(path), content=s)


def write_file(
    path_or_source: Union[str, SourceFile], content: str = None
) -> SourceFile:
    if isinstance(path_or_source, SourceFile):
        path = path_or_source.path
        content = path_or_source.content
    else:
        path = path_or_source
        if content is None:
            raise ValueError("Content must be provided when path is given")

    p = Path(path)
    p.write_text(content, encoding=_ENCODING)
    return SourceFile(path=str(path), content=content)


def create_timestamped_dir(base_path: Path, dir_format: str = "%Y-%m-%d %H.%M") -> Path:
    """
    Creates a directory inside base_path with the current timestamp as the name.

    Args:
        base_path (str): The root path where the directory will be created.
        dir_format (str): The datetime format string (default: "2025-02-23 20.14").

    Returns:
        str: The full path of the created directory.
    """
    timestamp = datetime.datetime.now().strftime(dir_format)
    result_path = base_path.joinpath(timestamp)
    result_path.mkdir(parents=True, exist_ok=True)

    return result_path
