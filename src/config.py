import tomllib
from pathlib import Path
from typing import TypedDict


class Config(TypedDict):
    str: any


_config = None


def read_config(path: Path = None):
    global _config

    if not path:
        path = "./cutup.toml"

    with open(str(path), "rb") as f:
        _config = tomllib.load(f)
        return _config


def get_config():
    global _config
    if _config is None:
        _config = read_config()
    return _config.copy()


# intended to be used when testing
def set_config(config: Config):
    global _config
    _config = config


def get_system_prompt():
    system_prompt = get_config()["agent"]["system_prompt"]
    return system_prompt


def get_model():
    return get_config()["agent"]["model"]


def get_temperature():
    return get_config()["agent"]["temperature"]


def get_verbose():
    return get_config()["general"]["verbose"]


def get_save_output():
    return get_config()["output"]["save"]


def get_ignore():
    return get_config()["search"]["ignore"]


def get_extensions():
    return frozenset(get_config()["search"].get("extensions", []))
