from pydantic_ai import Agent

from library import *
import json
from pathlib import Path
from time import sleep
from typing import List, Dict, Union, Tuple
#import coverage_utils

def open_codecov_coverage(filename: str) -> Dict:
    with open(filename, "r") as fp:
        return json.load(fp)

def strip_coverage(coverage_data: Dict, min_coverage: int = 70) -> Path:
    # Create a compact version of the codecov data
    stripped = []
    for entry in coverage_data.get("files", []):
        if entry.get("totals", {}).get("coverage", 100) < min_coverage:
            # Use an empty list if line_coverage is None
            line_coverage = entry.get("line_coverage") or []
            # Get line numbers with 0 hits and sort them
            uncovered = sorted([line[0] for line in line_coverage if line[1] == 0])
            stripped.append({
                "file": entry.get("name"),
                "coverage": entry.get("totals", {}).get("coverage"),
                "uncovered": uncovered
            })

    path = Path("stripped.json")
    path.write_text(json.dumps(stripped))
    return path

def shard_coverage(coverage_data: Dict) -> List[Path]:
    # splits the codecov json into one separate file per file in listed in the coverage
    # this is done the agent can have simple access to the coverage data file it wants in our repo
    # so it's a poor man's sharding basically, instead of reducing the resolution of the coverage (eg removing line coverage)
    # it's all quickly accessible lazily without needing much data
    # Since we re-create the agent the amount of data that any individual LLM instance is sent is quite small
    base_dir = Path("./")
    base_dir.mkdir(exist_ok=True)
    shards: list[Path] = []
    for entry in coverage_data.get("files", []):
        file_name = entry.get("name")
        if file_name:
            target_path = base_dir / file_name
            target_path.parent.mkdir(exist_ok=True, parents=True)
            target_path.write_text(json.dumps(entry))
            shards.append(target_path.resolve())
    return shards

def prepare_coverage() -> Tuple[Path, list[Path]]:
    """Returns a tuple with the stripped coverage and the shards, in other words
    the first element is the path for the whole coverage file but stripped down, t
    he other contains a list of all files with detailed coverage for each one"""
    coverage_dir = "./coverage"
    original_coverage_file = "codecov.json"

    with pushd(coverage_dir):
        json_data = open_codecov_coverage(original_coverage_file)
        shards = shard_coverage(json_data)
        stripped = strip_coverage(json_data)

        return stripped, shards.copy()


project_dir = config.get_project_dir()
e2e_tests = "cypress/**/app/*.e2e.js"
_, all_files = prepare_coverage()
decision_logs = []

with pushd(project_dir):
    for e2e_test in find(e2e_tests):
        decision_log = f"{e2e_test.name}-log.md"
        instructions = [
            "# Test Coverage Analysis Task",

            "## Files to Analyze",
            f"1. E2E test file: path://(project)/{e2e_test}",
            "2. All imports from the E2E test file, located at base directory: path://(project)/cypress/integration",
            "   Example: an import for '../utils/app/startRemoteTestOccasion' resolves to path://(project)/cypress/integration/utils/app/startRemoteTestOccasion.js",
            "3. Production code located at:",
            "   - path://(project)/app/src",
            "   - path://(project)/result/src",
            "4. Testing code located at:",
            "   - path://(project)/cypress",
            "5. Code coverage data is located at path://coverage",
            "   - Each production file has a matching path under /coverage, with identical structure and extension",
            "   - Example: `app/src/components/MyComponent.jsx` → `coverage/app/src/components/MyComponent.jsx`",
            "   - Coverage files include **line-by-line coverage data** — use this to identify untested logic",
            "6. Use `fileexists(path: str)` before attempting to read any file.",
            "7. Use `listfiles(path, ...)` to discover files in directories (e.g., when resolving imports or searching for `.jsx` components).",

            "## Analysis Process",
            "1. For each production file referenced in the E2E test, examine its corresponding test coverage data at the matching path in `/coverage`.",
            "2. When reading files under `/app/src` or `/result/src`, always cross-reference with test coverage.",
            "3. Prioritize examining production code and coverage gaps first.",
            "4. If a file appears to be missing coverage or doesn’t exist, document that.",
            "5. Keep a running log of your process, expectations, observations, and decisions inside the Markdown output file.",

            "## Logging and Iteration Strategy",
            "1. Continuously document your thought process in the Markdown output:",
            "   - what you expected,",
            "   - what you searched for,",
            "   - what worked or failed,",
            "   - what conclusions you drew.",
            "2. Structure your log like a journal of steps taken — this will allow future versions of this analysis to improve upon your work.",
            "3. Before starting a new analysis run, read the existing Markdown log to avoid repeating the same investigations or mistakes.",

            "## Output Requirements",
            f"1. Write all results and process logs to: touch://{decision_log}",
            "2. Use Markdown formatting.",
            "3. Be concise and honest — only suggest tests where they truly add value.",
            "4. If coverage is adequate, clearly state so.",
            "5. For each suggestion, provide a specific rationale based on the code and coverage structure.",
        ]

        final_prompt = prompt(instructions)
        log(final_prompt)
        decision_logs.append(decision_log)
        sleep(10)

with open('decisions.md', 'w') as outfile:
    outfile.write('\n\n'.join(open(f).read() for f in decision_logs))
