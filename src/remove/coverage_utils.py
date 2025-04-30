import json
from pathlib import Path
from typing import List, Dict

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
