format:
    uv run black .

lint:
    uv run ruff check .
    unv run  mypy .

test:
    (cd tests && uv run pytest)

clean:
    find . -type f -name "*.pyc" -delete && uv cache clean && rm -rf .venv

all: format lint test
