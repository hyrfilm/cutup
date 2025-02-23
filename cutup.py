import typer
from src.main import main
from src.search import search_files
from src.io import read_file, write_file

if __name__ == "__main__":
    typer.run(main)
