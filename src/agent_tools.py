import os
from pathlib import Path
from typing import Union, List

from pydantic_ai import Agent
from pydantic_ai.settings import ModelSettings

from src import config
from src import io
from src.console import log, with_cycling_spinner, indented_log
from src.io import SourceFile
from src.io import create_timestamped_dir

agent = Agent()
output_dir = Path("./")

def initialize():
    global agent, output_dir

    if config.save_output:
        output_dir = create_timestamped_dir(config.cwd)

    if not os.getenv('OPENAI_API_KEY'):
        log('[yellow]OPENAI_API_KEY not set - creating Agent stub')
        agent = Agent()
    else:
        log('[green]Creating OpenAI agent')
        agent = Agent[SourceFile](config.model,
                                  result_type=List[SourceFile],
                                  system_prompt=config.system_prompt,
                                  model_settings=ModelSettings(temperature=config.temperature))

@with_cycling_spinner("runner")
def process(prompt: Union[List[str] | str], **kwargs):
    amountDone = ("[dark green]#{done} / {total} files[/dark green]".format(**kwargs)) # make into helper, name log instead of rlog
    indented_log(f"[magenta]Processing[/magenta] :robot: {amountDone}")

    if isinstance(prompt, list):
        user_prompt = "\n".join(prompt)
    else:
        user_prompt = prompt

    result = agent.run_sync(user_prompt)
    if not config.save_output:
        indented_log(f"Output saving disabled - skipping writing files")
        return

    for file in result.data:
        indented_log(f"\n\nWriting: '{file.path}'")
        io.write_file(output_dir / file.name, file.content)


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
    indented_log(f"\t:robot: <== {path}")
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
    indented_log(f"\t:robot: ==> {path}")
    file = io.write_file(path, content)
    return file