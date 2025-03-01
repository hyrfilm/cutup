import pytest
from pathlib import Path
from src.fileio.io import read_file, write_file

FIXTURES_DIR = Path(__file__).parent / "fixtures"
TEST_FILE_PATH = FIXTURES_DIR / "testfile.txt"
TEST_FILE_CONTENT = "testing 1, 2, 1, 2"


def test_read_file():
    result = read_file(str(TEST_FILE_PATH))
    assert result.path == str(TEST_FILE_PATH)
    assert result.content == TEST_FILE_CONTENT


def test_write_file_with_path_and_content(tmp_path):
    test_path = tmp_path / "test_write.txt"
    content = "file content"
    result = write_file(str(test_path), content)
    assert test_path.read_text(encoding="utf-8") == content
    assert result.path == str(test_path)
    assert result.content == content


def test_write_file_with_sourcefile(tmp_path):
    test_path = tmp_path / "test_write.txt"
    source_file = SourceFile(path=str(test_path), content="file content")
    result = write_file(source_file)
    assert test_path.read_text(encoding="utf-8") == "file content"
    assert result.path == source_file.path
    assert result.content == source_file.content


def test_write_file_raises_value_error():
    with pytest.raises(ValueError):
        write_file("test.txt")
