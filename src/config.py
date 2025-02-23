from typing import TypedDict
import tomllib  # Python 3.11+


class Config(TypedDict):
    str: any


_config: Config = {
    "general": {},
    "search": {},
    "openai": {},
}

try:
    with open("./cutup.toml", "rb") as f:
        _config = tomllib.load(f)
except FileNotFoundError:
    print("No cutup.toml configuration found - using defaults.")

extensions = frozenset(_config["search"].get("extensions", []))
ignore = tuple(_config["search"].get("ignore", []))

model = _config["openai"].get("model")
system_prompt = _config["openai"].get("system_prompt")
user_prompt = _config["openai"].get("user_prompt")
code_delimiter = _config["openai"].get("code_delimiter")
text_delimiter = _config["openai"].get("text_delimiter")
example_code = _config["openai"].get("example_code")
example_text = _config["openai"].get("example_text")
reflection_request = _config["openai"].get("reflection_request")
verbose = _config["general"].get("verbose", False)
write_reference = _config["general"].get("write_reference", True)


def set_verbose(flag: bool):
    global verbose
    verbose = flag
