format:
    black .

lint:
    ruff check .
    mypy .

test:
    pytest

all: format lint test
