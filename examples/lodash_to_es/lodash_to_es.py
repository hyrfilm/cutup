import re
from pathlib import Path

from library import *
from postgres_to_ts.tables_to_interfaces import instructions

as_markdown = destination_format=DstFormat.MARKDOWN
text_documentation = curl("https://lodash.com/docs/", destination_format=as_markdown)
print(text_documentation)

rows = text_documentation.splitlines()
chapters = split_rows_by_delimiter(rows, '### `')
function_name_regexp = re.compile(r"`_(.*?)\(")
output_file = "lodash_vs_es2022.md"
examples = read_file("examples.txt")

for rows in chapters:
    condensed = []

    try:
        if len(rows) < 16:
            continue
        signature = rows[0]
        match = function_name_regexp.search(signature)
        name = "unknown_function"
        if match:
            name = match.group(1)
            condensed.append(f"Function: {name}")

        condensed.append(signature)
        description = rows[4]
        condensed.append(description)
        ArgsHeader = rows[10]
        condensed.append(ArgsHeader)
        Args = rows[12]
        condensed.append(Args)
        ReturnHeader = rows[12]
        condensed.append(ReturnHeader)
        ReturnValue = rows[14]
        condensed.append(ReturnValue)

        if name:
            path = Path(name).with_suffix('.txt')
            path.write_text("\n".join(condensed))

        instructions = [f"Your task is to read the file that documents the following lodash function: file://{path} ",
                f"and then write down this summary in Markdown format: file://{output_file} ",
                f"But what's most important of all is that you evaluate if a standard JS-library function can",
                f"be used instead. Before you write to file://{output_file} make sure to read from it so that",
                f"you don't over-write anything.",
                f"{examples}"]

        prompt(instructions)


    except IndexError:
        break