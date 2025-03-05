import string

import html2text
from markdownify import markdownify as md


def html_to_text(html: str) -> str:
    text_maker = html2text.HTML2Text()
    text_maker.ignore_links = True
    text_maker.ignore_images = True
    text_maker.escape_snob = False
    text_maker.single_line_break = True
    text_maker.inline_links = False
    text_maker.protect_links = False
    text_maker.bypass_tables = True
    text_maker.ignore_tables = True
    text_maker.mark_code = True
    text_maker.wrap_links = False
    text_maker.wrap_list_items = False
    text_maker.wrap_tables = False
    text_maker.decode_errors = "ignore"
    return text_maker.handle(html)


def html_to_markdown(html: str) -> str:
    # TODO: This will probably need tweaks
    return md(html)

def slugify(s: str) -> str:
    def slugify_char(c: str) -> str:
        if c in (string.ascii_lowercase + '0123456789'):
            return c
        return ''
    chars = [slugify_char(c) for c in s]
    return ''.join(chars)

def s_l_u_g_i_f_y(s: str) -> str:
    def slugify_char(c: str) -> str:
        if c.isalnum():
            return c
        return '-'

    slug = [slugify_char(c) for c in s]
    return "-".join(slug)
