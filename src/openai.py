from rich._spinners import SPINNERS
from rich import pretty
from openai import OpenAI

from . import config
from .config import text_delimiter
from .log import spinner, rlog

client = OpenAI()

spinner_list = list(SPINNERS.keys())
spinner_index = spinner_list.index("runner")  # Start with 'runner'


def process_completion(completion, name):
    if not completion or not completion.choices[0].message.content:
        return "", "", name

    content = completion.choices[0].message.content

    if config.example_code in content:
        content = content.replace(config.example_code, config.code_delimiter)
        content = content.replace(config.example_text, config.text_delimiter)

        code = "".join(content.split(config.code_delimiter)).strip()
        text = "".join(content.split(config.text_delimiter)).strip()

        if text_delimiter not in content:
            text = ""

        if not code:
            code = ""
        if not text:
            text = ""

        return code, text, name


def get_chat_completion(user_context: str):
    global spinner_index

    user_content = "\n".join([config.user_prompt, user_context])
    current_spinner = spinner_list[spinner_index]

    stop_spinner = spinner(current_spinner)
    spinner_index = (spinner_index + 1) % len(spinner_list)
    completion = ""
    reflection = ""

    completion = client.chat.completions.create(
        model=config.model,
        messages=[
            {"role": "system", "content": config.system_prompt},
            {"role": "system", "content": user_content},
        ],
    )
    stop_spinner()

    if config.reflection_request:
        rlog(
            "[blink]:thinking_face: Sending reflection request :thinking_face:[/blink]"
        )
        stop_spinner = spinner("balloon")

        reflection = client.chat.completions.create(
            model=config.model,
            messages=[
                {"role": "system", "content": config.system_prompt},
                {"role": "system", "content": config.reflection_request},
            ],
        )
        stop_spinner()

    if config.verbose:
        rlog("default answer:\n")
        pretty.pprint(completion)
    if config.reflection_request:
        rlog("reflected answer:\n")
        pretty.pprint(reflection)

    results = []
    results.append(process_completion(completion, name="default"))
    results.append(process_completion(reflection, name="reflection"))
    result = [result for result in results if result is not None]

    return result
