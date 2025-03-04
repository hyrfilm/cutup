import re

from library import *

# read the file into a list of rows
with open("schema.sql") as f:
    all_rows = f.readlines()

# for each occurrence of the search term, split the list sub-lists
search_term = "CREATE TABLE"
sub_lists = split_rows_by_delimiter(all_rows, search_term)
pattern = re.compile(f"CREATE TABLE [^;]*;")

all_tables = []

for rows in sub_lists:
    # put the sub-list back together into a single string
    text_fragment = "".join(rows)
    # does it contain a table definition?
    table_match = re.match(pattern, text_fragment)
    if table_match:
        # yes, it does - keep it
        table_definition = table_match.group()
        all_tables.append(table_definition)

# when referring to a file using path:// (as below) it needs to be verified to exist
ts_file = "interfaces.ts"
touch(ts_file)

# instructive examples usually improves the quality of the output
examples = read_file("examples.txt")

for file_nr, table_declaration in enumerate(all_tables, start=1):
    sql_file = f"{file_nr}.sql"
    write_file(sql_file, table_declaration)
    instructions = [
        f"Refactor this code by reading the SQL-file path://{sql_file} "
        f"and creating a corresponding TypeScript interface.",
        f"Use standard JS/TS naming conventions, e.g. PascalCase for interfaces and fields.",
        f"Write the result to path://{ts_file} but make sure to read the file before so you don't overwrite what's already there.",
        f"{examples}",
    ]
    prompt(instructions)

# This is another way to do it, all at once, which will go faster
# and cheaper too  I guess, but then you have to make sure
# that it generates everything, doesn't run out of tokens etc
# table_file, interface_file = "tables.sql", "interfaces.ts"
# like doesn't run out of tokens etc
# write_file(f"{table_file}", "\n".join(all_tables))
#
# instructions = [
#     f"This refactoring consists of making sure each SQL table has a TypeScript interface",
#     f"For each table found in: path://{table_file} you should convert it to a typescript interface",
#     f"Use standard JS/TS naming conventions, e.g. PascalCase for interfaces and fields",
#     f"Write the result to this file path://{interface_file}",
#     f"{examples}",
# ]
# prompt(instructions)
