from src.dict_utils import has_all


def test_has_all():
    d = {"a": 1, "b": 2, "c": 3}
    assert has_all(d) == True
    assert has_all(d, "a") == True
    assert has_all(d, "a", "b") == True
    assert has_all(d, *["a", "b"]) == True
    assert has_all(d, *["a", "b", "c"]) == True
    assert has_all(d, *["b", "c"]) == True
    assert has_all(d, *["b", "c", "d"]) == False
    assert has_all(d, "d") == False
