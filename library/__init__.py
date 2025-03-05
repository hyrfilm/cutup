# the library module is intended to make it easy for scripts
# to just import the public utility functions

from src.console import log, with_spinner, indented_log
from src.io import read_file, write_file, touch
from src.search import search_files
from src.insertion import split_at, split_rows_by_delimiter
from src.prompting import prompt
from src.env_vars import get_env_var, print_env_vars
from src.http_utils import curl, SrcFormat, DstFormat, html_to_text, html_to_markdown
from src.parsing import s_l_u_g_i_f_y, slugify
