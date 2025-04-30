from typing import List, Tuple, Callable, Union

from .console import log
from .path_ref import resolve
from .agent_tools import send_to_agent


def format_errors(errors):
    msg = f"{len(errors)} errors found in instructions"
    for e, line, line_str in errors:
        msg += f"\n{e} when processing line {line} ({line_str})"
    return msg


def preprocess(instructions: Union[str, List[str]]):
    if isinstance(instructions, str):
        assert instructions is not None
        assert instructions.strip() != ""
        instructions = [instructions]

    processed_instructions = []
    errors: [Tuple[Exception, int, str]] = []
    for row, instruction in enumerate(instructions, start=1):
        try:
            resolved = resolve(instruction)
            processed_instructions.append(resolved)
        except Exception as ex:
            errors.append((ex, row, instruction))

    if not errors:
        return processed_instructions
    else:
        raise Exception(format_errors(errors))

def format_prompt(prompt_list):
    # adding padding between each row in the prompt
    # makes it less likely that using it would cause frustation formatting
    # issues when using variales
    return [ f" {row} " for row in prompt_list ]

def prompt(instructions: Union[str, List[str]], send: Callable[[str], None] = None):
    if send is None:
        send = send_to_agent

    prompt_list = preprocess(format_prompt(instructions))
    final_prompt = "\ n".join(prompt_list)
    send(final_prompt)
    return final_prompt
