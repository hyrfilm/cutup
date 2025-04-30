import os
from pathlib import Path
from typing import List, Set, Optional

from openai import BaseModel
from pydantic_ai import Agent
from pydantic_ai.settings import ModelSettings

from .search import pattern_search
from .dict_utils import has_all
from . import config

from src import io
from src.console import log, with_cycling_spinner, indented_log

agent = None

model_providers = {
    "OPENAI_API_KEY": "[dodger_blue3]Creating OpenAI agent[/dodger_blue3]",
    "ANTHROPIC_API_KEY": "[indian_red1]Creating Anthropic agent[/indian_red1]",
}

class SourceFile(BaseModel):
    """
    Represents a source file with its path and content.

    Attributes:
        path (str): The file path.
        content (str): The content of the file.
    """

    path: str
    content: str

def create_agent(stub=False) -> Agent:
    global agent
    agent = create_agent_config(stub)

    @agent.tool_plain
    def readfile(path: str) -> str:
        """
        Reads the content of a file and returns it as a string.

        Args:
            path (str): The path to the file.

        Returns:
            str: the content of the file..

        Raises:
            ValueError: If the path does not exist or is not a file.
        """
        indented_log(f":robot: <== {path}\t[cyan][read][/cyan]")
        content = io.read_file(path)
        return content

    @agent.tool_plain
    def writefile(path: str, content: str) -> None:
        """
        Writes to a file.

        Args:
            path (path: str The file path to write to.
            content (str: str): The content to write.

        Returns:
            None

        Raises:
            ValueError: If either the path is not provided or the content is empty.
        """
        indented_log(f":robot: ==> {path}\t[orange][write][/orange]")
        io.write_file(path, content)

    @agent.tool_plain
    def listfiles(path: str, content_pattern: str ="", file_glob: str = "*", extensions: Optional[Set[str]] = None) -> List[str]:
        """
        Lists files under a directory matching optional filters.

        Args:
            path (str): Directory path.
            content_pattern (str): Regex to match file content.
            file_glob (str): Glob pattern to match filenames.
            extensions (Optional[Set[str]]): File extensions to include.

        Returns:
            List[str]: Absolute paths of matching files.
        """
        path = Path(path)
        indented_log(f"🤖🔎📁 Looking for '{content_pattern}' in files '{file_glob}' at {path.absolute()}...")
        files = pattern_search(content_pattern, path, files=file_glob, extensions=extensions)
        log(f"\nFound {len(files)} files.")
        return [str(f.absolute()) for f in files]

    @agent.tool_plain
    def fileexists(path: str) -> bool:
        """
        Checks whether a file or directory exists at the given path.

        Args:
            path (str): The path to check.

        Returns:
            bool: True if the file or directory exists, False otherwise.
        """
        from pathlib import Path
        return Path(path).exists()

    return agent


def create_agent_config(stub):
    if stub:
        return Agent()
    for api_key in model_providers:
        if os.getenv(api_key):
            log(model_providers[api_key])
            return Agent[SourceFile](
                model=config.get_model(),
                result_type=List[SourceFile],
                system_prompt=config.get_system_prompt(),
                model_settings=ModelSettings(temperature=config.get_temperature()),
            )
    else:
        log("[blink]No API key set - creating Agent stub[/blink]")
        return Agent()


@with_cycling_spinner("runner")
def send_to_agent(user_prompt: str, **kwargs):
    if has_all(kwargs, "done", "total"):
        amount_done = "[dark green]#{done} / {total} files[/dark green]".format(
            **kwargs
        )  # make into helper, name log instead of rlog
        indented_log(f"[magenta]Processing[/magenta] :robot: {amount_done}")

    result = agent.run_sync(user_prompt)
    # for verbosity and needs more structured/formatted output
    # for message in result.new_messages():
    #    print(message)

    if not config.get_save_output():
        indented_log(f"Output saving disabled - skipping writing files")
        return

    # for data in result.data:
    #    print(data)

    output_dir = io.create_timestamped_dir()

    for file, content in result.data:
        output_path = output_dir / Path(file)
        indented_log(f"\n\nWriting: {output_path}")
        io.write_file(str(output_path), content)
