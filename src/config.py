import tomllib  # Python 3.11+
from pathlib import Path
from typing import TypedDict


class Config(TypedDict):
    str: any


_config: Config = {
    "general": {},
    "search": {},
    "agent": {},
    "output": {},
}

try:
    with open("./cutup.toml", "rb") as f:
        _config = tomllib.load(f)
except FileNotFoundError:
    print("No cutup.toml configuration found - using defaults.")

extensions = frozenset(_config["search"].get("extensions", []))
ignore = tuple(_config["search"].get("ignore", []))
model = _config["agent"].get("model", "openai:gpt-o1")
system_prompt = _config["agent"].get("system_prompt")
temperature = _config["agent"].get("temperature", 1.0)
verbose = _config["general"].get("verbose", False)
save_output = _config["output"].get("save", True)

# TODO: Write verbose into config in the same way as all the other settings
def set_verbose(flag: bool):
    global verbose
    verbose = flag
