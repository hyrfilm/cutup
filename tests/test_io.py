import pytest
from pathlib import Path
from src.io import read_file, write_file

FIXTURES_DIR = Path(__file__).parent / "fixtures"
TEST_FILE_PATH = FIXTURES_DIR / "testfile.txt"
TEST_FILE_CONTENT = "testing 1, 2, 1, 2"


def test_read_file():
    result = read_file(str(TEST_FILE_PATH))
    assert result == TEST_FILE_CONTENT


def test_write_file(tmp_path):
    test_path = tmp_path / "test_write.txt"
    content = "file content"
    write_file(str(test_path), content)
    assert test_path.read_text(encoding="utf-8") == content
