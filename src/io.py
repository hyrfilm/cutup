from typing import Union
from pathlib import Path

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
