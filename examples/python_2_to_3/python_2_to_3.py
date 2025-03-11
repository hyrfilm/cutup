from pathlib import Path

from library import *

shell("rm -rf ./repo")
shell("git clone https://github.com/hyrfilm/skivvy ./repo")

# make sure the config is set to find python files
update_config(["search", "extensions"], [".py"])
set_env_var("repo", "./repo/skivvy")

files = search_files("", Path(get_env_var("repo")))

for src_file in files:
    instructions = [
        f"Refactor this python code from python 2 to python 3."
        f"Only make changes needed for it to run on the latest python version.",
        f"Read the file: path://{src_file} and then write the refactored code to the same file.",
    ]

    prompt(instructions)
