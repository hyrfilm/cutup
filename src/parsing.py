import html2text
from markdownify import markdownify as md

def html_to_text(html: str) -> str:
    text_maker = html2text.HTML2Text()
    text_maker.ignore_links = True
    text_maker.ignore_images = True
    text_maker.escape_snob = True
    text_maker.single_line_break = True
    text_maker.inline_links = False
    text_maker.protect_links = False
    text_maker.bypass_tables = True
    text_maker.ignore_tables = True
    text_maker.mark_code = False
    text_maker.wrap_links = False
    text_maker.wrap_list_items = False
    text_maker.wrap_tables = False
    text_maker.decode_errors = 'ignore'
    return text_maker.handle(html)

def html_to_markdown(html: str) -> str:
    #TODO: This will probably need tweaks
    return md(html)
