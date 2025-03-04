from os import getcwd, path
import pytest

from src.env_vars import ensure_env_vars
from src.path_ref import resolve_path_ref, consume, UnresolvedPathError


def test_consume_prefix():
    success, matched, rest = consume("path://")
    assert success == True
    assert matched == "path://"
    assert rest == ""

    success, matched, rest = consume("path://this is the rest")
    assert success == True
    assert matched == "path://"
    assert rest == "this is the rest"

    success, matched, rest = consume("path:/this is the rest")
    assert success == False
    assert matched == ""
    assert rest == "path:/this is the rest"


def test_consume_variable():
    success, matched, rest = consume("${my_variable}something else")
    assert success == True
    assert matched == "my_variable"
    assert rest == "something else"

    success, matched, rest = consume("${  my_variable   }")
    assert success == True
    assert matched == "my_variable"
    assert rest == ""

    success, matched, rest = consume("no variable here")
    assert success == False
    assert matched == ""
    assert rest == "no variable here"


def test_path_resolving():
    script_dir = path.join(getcwd(), "fixtures/script")
    repo_dir = path.join(getcwd(), "fixtures/repo")

    ensure_env_vars(
        ("cwd", script_dir),
        ("repo", repo_dir),
    )

    path1 = resolve_path_ref("path://script_file.txt")
    path2 = resolve_path_ref("path://${cwd}/script_file.txt")
    path3 = resolve_path_ref("path://${cwd}./script_file.txt")
    path4 = resolve_path_ref("path://${cwd}../../fixtures/script/script_file.txt")

    assert path1 == path2 == path3 == path4

    path1 = resolve_path_ref("path://${repo}repo_file.txt")
    path2 = resolve_path_ref("path://${repo}/repo_file.txt")
    path3 = resolve_path_ref("path://${repo}./repo_file.txt")

    assert path1 == path2 == path3


def test_raises_exception_if_failing_to_resolve():
    ensure_env_vars(
        ("cwd", "./"),
        ("repo", "./"),
    )

    with pytest.raises(UnresolvedPathError):
        resolve_path_ref("path://dude_where_is_my_file.txt")
    with pytest.raises(UnresolvedPathError):
        resolve_path_ref("path://${var_does_not_exist}")
