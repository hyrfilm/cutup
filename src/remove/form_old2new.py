import os
from pathlib import Path

from library import *

new_dir, old_dir = tuple([os.path.join(get_env_var("repo"), p) for p in ["common/src/forms", "backend/dev/form_sources"]])

example_modern_form = os.path.join(new_dir, "MANSA_MAX_REMIX.jsonc")
example_legacy_form = os.path.join(old_dir, "MANSA.json")

update_config(["search", "extensions"], [".json"])
files = search_files("", Path(old_dir))

for src_file in files:
    #dst_file = os.path.join(new_dir, f"{src_file.stem}.jsonc")
    instructions = [
        f"Read the file: path://{example_legacy_form} - this is an example of an old legacy form definition.",
        f"Read the file: path://{example_modern_form} - this is an example of a modern form definition.",
        f"Read the legacy form path://{src_file} and convert it to a modern form and write it to the directory path://{new_dir} as a jsonc file.",
    ]

    prompt(instructions)
