import requests
from typing import Union
from enum import Enum
from .parsing import convert_html_to_plain_text, convert_html_to_markdown


class SrcFormat(Enum):
    HTML = "html"
    JSON = "json"


class DstFormat(Enum):
    AS_IS = "as-is"
    PLAIN = "plain"
    MARKDOWN = "markdown"


def curl(
    url: str,
    source_format: SrcFormat = SrcFormat.HTML,
    destination_format: DstFormat = DstFormat.AS_IS,
) -> Union[str, dict]:
    response = requests.get(url)

    if source_format == SrcFormat.JSON:
        if destination_format == DstFormat.AS_IS:
            return response.json()
        else:
            raise ValueError(
                "Unsupported destination format for JSON source. Use 'as-is'."
            )

    html_content = response.text

    if destination_format == DstFormat.AS_IS:
        return html_content
    elif destination_format == DstFormat.PLAIN:
        return convert_html_to_plain_text(html_content)
    elif destination_format == DstFormat.MARKDOWN:
        return convert_html_to_markdown(html_content)
    else:
        raise ValueError(
            "Unsupported destination format. Use 'as-is', 'plain', 'markdown', or 'json'."
        )
