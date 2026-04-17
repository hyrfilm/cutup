import re
from pathlib import Path

from library import *

conflict_regexp = re.compile(r"<<<<<<<|=======|>>>>>>>")
schema = open("autoresolve.schema.json").read()
schema_examples = open("autoresolve.examples.json").read()


for conflict_file in grep(conflict_regexp, Path('/Users/jonasholmer/devroot/dummy_repo/skivvy')):
    instructions = [f"""
    You are a merge conflict classifier and resolution agent.

    Classify each conflict as one of:
    - auto_resolve
    - auto_resolve_review
    - propose_resolution
    - escalate_human

    Judge based on intent, commutativity, and risk, not line overlap.

    Read the file path:{conflict_file}
    For each conflict:
    1. Summarize branch A intent.
    2. Summarize branch B intent.
    3. Decide whether the changes likely commute.
    4. Assess risk if merged incorrectly.
    5. Use validation results to adjust confidence.
    6. Choose the classification.
    7. If classification is not escalate_human, provide a merged-resolution strategy.
    8. If classification is escalate_human, state the exact human decision required.
    
    Be conservative when semantics are unclear.
    Write this to the file path:{conflict_file}.autoresolve.json
    Use  the following schema:
    {schema}
    Do not write chain-of-thought.
    write only JSON matching the required schema.

    Examples:
    {schema_examples}
    """
    ]

    prompt(instructions)
