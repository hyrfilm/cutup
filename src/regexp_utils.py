import re

flags = re.NOFLAG


def ignore_casing():
    global flags
    flags |= re.IGNORECASE


def compile(pattern):
    return re.compile(r"\b" + re.escape(pattern) + r"\b", flags)
