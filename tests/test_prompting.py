from pathlib import Path

import pytest

from src.env_vars import ensure_env_vars
from src.prompting import prompt


class StubAgent:
    def __init__(self):
        self.messages = []

    def send(self, message):
        self.messages.append(message)

    def get_prompt(self):
        return "\n".join(self.messages)


def test_prompt_with_joke_instructions():
    agent = StubAgent()
    instructions = [
        "I want you to tell me a joke.",
        "The joke should not be funny.",
        "It should be sad",
    ]
    prompt(instructions, send=agent.send)

    expected_output = (
        "I want you to tell me a joke.\nThe joke should not be funny.\nIt should be sad"
    )
    assert expected_output == agent.get_prompt()


def test_prompt_with_path_refs():
    agent = StubAgent()
    repo_file = Path("./fixtures/repo")
    script_file = Path("./fixtures/script")

    ensure_env_vars(("repo", str(repo_file)), ("cwd", str(script_file)))

    instructions = [
        "I want you to read from the file path://${repo}/repo_file.txt and write it to path://${cwd}/script_file.txt"
    ]
    prompt(instructions, send=agent.send)

    assert "I want you to read from" in agent.get_prompt()
    assert "and write it to" in agent.get_prompt()


def test_prompt_with_invalid_path_refs():
    agent = StubAgent()

    instructions = ["I want you to read from the files you find in path://{invalid}"]

    with pytest.raises(Exception) as e:
        prompt(instructions, send=agent.send)
