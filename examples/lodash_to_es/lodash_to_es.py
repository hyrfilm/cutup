import re
from pathlib import Path

from library import *

as_markdown = destination_format=DstFormat.MARKDOWN
text_documentation = curl("https://lodash.com/docs/", destination_format=as_markdown)

rows = text_documentation.splitlines()
chapters = split_rows_by_delimiter(rows, '### `')
function_name_regexp = re.compile(r"`_(.*?)\(")
output_file = "lodash_vs_es2022.txt"
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
            name = slugify(name)
            path = Path(name).with_suffix('.txt')
            path.write_text("\n".join(condensed))

        touch(output_file)

        instructions = [f"Your task is to first read the documentation of a lodash function here: path://{path} ",
                        f"You should then either try to re-write the documentation in best way possible."
                        f"After the lodash section, you should always add a section that explains if similar functionality"
                        f"nowadays have been added to the Javascript standard library or if you can achieve something similar"
                        f"using pure Javascript. Finally you need to write this to path://{output_file} which may already",
                        f"contain documentation which you need to preserve. It's also important that the documentation"
                        f"is consistent so it's important that you read path://{output_file} before writing to it.",
                        f"{examples}"]

        prompt(instructions)


    except IndexError:
        break