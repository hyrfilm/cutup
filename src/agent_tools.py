import os
from typing import Union, List

from pydantic_ai import Agent

from pydantic_ai.settings import ModelSettings
from rich import pretty

from src.log import rlog, with_spinner
from src.io import SourceFile
from src import io
from src import config


if not os.getenv('OPENAI_API_KEY'):
    rlog('[yellow]OPENAI_API_KEY not set - creating Agent stub')
    agent = Agent()
else:
    rlog('[green]Creating OpenAI agent')
    agent = Agent[SourceFile](config.model,
                              result_type=List[SourceFile],
                              system_prompt=config.system_prompt,
                              model_settings=ModelSettings(temperature=config.temperature))
from src.io import SourceFile

@with_spinner(style="dots8", message=f"Sending to {config.model}")
def process(prompt: Union[List[str]|str]):
    if isinstance(prompt, list):
        user_prompt = "\n".join(prompt)
    else:
        user_prompt = prompt

    result = agent.run_sync(user_prompt)
    pretty.pprint(result)


@agent.tool_plain()
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
    rlog(f":robot: <== {path}")
    content = io.read_file(path)
    return content


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
    rlog(f":robot: ==> {path}")
    file = io.write_file(path, content)
    return file
