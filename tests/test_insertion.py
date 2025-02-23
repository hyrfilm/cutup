from src.insertion import split_at


def test_basic_split():
    text = ["The", "quick", "brown", "fox", "jumps", "over", "lazy", "dog"]
    indices = [2, 5]
    result = split_at(text, indices)
    assert result == (
        ["The", "quick"],
        ["brown", "fox", "jumps"],
        ["over", "lazy", "dog"],
    )


def test_newline_text():
    text = "I am that I am\nThat I am\nI think\nI am".split("\n")
    indices = [1, 3]
    result = split_at(text, indices)
    assert "\n".join(result[0]) == "I am that I am"
    assert "\n".join(result[1]) == "That I am\nI think"
    assert "\n".join(result[2]) == "I am"


def test_burroughsp():
    original = ["I can feel", "the heat closing", "in like something", "in a bad dream"]
    indices = [1, 2]
    parts = split_at(original, indices)

    # Mix the parts in a different order
    mixed = parts[1] + parts[0] + parts[2]
    assert mixed == [
        "the heat closing",
        "I can feel",
        "in like something",
        "in a bad dream",
    ]


def test_edge_cases():
    text = ["one", "two", "three", "four", "five"]
    assert split_at(text, []) == (text,)
    assert split_at(text, [0]) == ([], text)
    assert split_at(text, [4]) == (["one", "two", "three", "four"], ["five"])
    assert split_at(text, [99]) == (text,)


def test_out_of_range_indices(capsys):
    text = ["alpha", "beta", "gamma"]
    result = split_at(text, [-1, 5])
    captured = capsys.readouterr()
    assert "Warning: Index -1 is out of range" in captured.out
    assert "Warning: Index 5 is out of range" in captured.out
    assert result == (text,)
