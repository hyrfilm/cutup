import tempfile
from pathlib import Path

from src.search import pattern_search

def test_pattern_search_finds_matching_files():
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test.js"
        test_file.write_text("This microphone permission is required")

        # Should match "microphone|mic|permission"
        matches = pattern_search("microphone|mic|permission", Path(tmpdir), extensions={".js"})
        assert test_file in matches
        assert len(matches) == 1

def test_pattern_search_respects_extensions():
    with tempfile.TemporaryDirectory() as tmpdir:
        test_file = Path(tmpdir) / "test.md"
        test_file.write_text("microphone")

        matches = pattern_search("microphone", Path(tmpdir), extensions={".js"})
        assert test_file not in matches
        assert len(matches) == 0

def test_pattern_search_respects_ignore():
    with tempfile.TemporaryDirectory() as tmpdir:
        ignored = Path(tmpdir) / "ignore_me.js"
        ignored.write_text("microphone")
        matches = pattern_search("microphone", Path(tmpdir), extensions={".js"}, ignore=("ignore_me",))
        assert matches == []
