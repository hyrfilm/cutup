import os

ENV_PREFIX = "CUTUP_"

CWD = "CWD"
REPO = "REPO"


def normalize(name: str) -> str:
    name = name.upper()
    if not name.startswith(ENV_PREFIX):
        name = ENV_PREFIX + name
    return name


def set_env_var(name: str, value: str):
    os.environ[normalize(name)] = value


def get_env_var(name: str, default=None) -> str:
    return os.environ.get(normalize(name), default)


def print_env_vars():
    print("Number of env vars: ", len(os.environ.items()))
    for key, value in os.environ.items():
        if key.startswith(ENV_PREFIX):
            print(f"{key}: {value}")


def ensure_env_vars(*env_vars):
    for name, value in env_vars:
        if not get_env_var(name):
            set_env_var(name, value)
