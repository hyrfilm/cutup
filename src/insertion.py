import pathlib
import re
from typing import List, Tuple

from . import regexp_utils
from . console import log


def clamp[T](value: T, minimum: T, maxmimum: T) -> T:
    """
    Clamp the value between the minimum and maximum values.

    :param value: The value to clamp.
    :param minimum: The minimum value.
    :param maxmimum: The maximum value.
    :return: The clamped value.
    """
    if value < minimum:
        return minimum
    if value > maxmimum:
        return maxmimum
    return value

def split_rows_by_delimiter(all_rows: list[str], delimiter: str) -> list[list[str]]:
    """
    Splits rows of text into sections based on a delimiter pattern. Each section 
    begins with a line containing the delimiter.

    Example:
        rows = [
            "Header text",
            "# Chapter 1",
            "Some content",
            "More content",
            "# Chapter 2",
            "Next section"
        ]
        sections = split_rows_by_delimiter(rows, "# Chapter")
        # Returns: [
        #   ["# Chapter 1", "Some content", "More content"],
        #   ["# Chapter 2", "Next section"]
        # ]

    Use cases:
        - Breaking up text files by section headers
        - Splitting documentation by markers
        - Parsing structured text files
        - Extracting content between known delimiters

    Args:
        all_rows (list[str]): Lines of text to split
        delimiter (str): Text pattern that marks the start of each section

    Returns:
        list[list[str]]: List of sections, where each section is a list of rows
    """
    delimiter_positions = [
        row_nr for row_nr, row_data in enumerate(all_rows) 
        if delimiter in row_data
    ]
    sections = split_at(all_rows, delimiter_positions)
    cleaned_sections = [section for section in sections if any(delimiter in row for row in section)]
    return cleaned_sections


def insert_comment(files: List[pathlib.Path], pattern: str):
    decider = InsertionHeuristics()

    for path in files:
        with path.open(mode="r", encoding="utf-8") as f:
            log(f"{path}")
            if not f.readable():
                log(":warning:", "Not readable")
                continue
            lines = f.readlines()

            # new_lines, insert_index = insert_comment_after_pattern(lines, pattern, comment, decider)
            incisions, _warnings = find_insertion_points(
                lines, pattern, heuristics=decider
            )
            colors = {False: "gray italic", True: "green bold"}
            toggle = False
            for segments in split_at(lines, incisions):
                splice = "".join(segments)
                color = colors[toggle]
                msg = "".join([f"[{color}]", splice, f"/[{color}]"])
                log(msg)
                toggle = not toggle

                log("-----------------------------------\n\n")


class InsertionHeuristics:
    """
    A helper class to determine whether a line in a JS file is a "good place"
    to insert the comment. We can add as many heuristics as we want.
    """

    def __init__(self, line_endings=(";"), allow_blank_lines=True):
        """
        :param line_endings: A tuple of endings that might signal statement completion.
                             E.g. (";", "})", "})?", etc.?) for your code style.
        :param allow_blank_lines: If True, blank lines are considered good insertion points.
        """
        self.line_endings = line_endings
        self.allow_blank_lines = allow_blank_lines

    def ends_with_semicolon(self, line: str) -> bool:
        """Heuristic: The line ends with a semicolon (after trimming)."""
        return line.strip().endswith(";")

    def is_blank_line(self, line: str) -> bool:
        """Heuristic: The line is blank or only whitespace."""
        return not line.strip()  # True if empty after strip

    def ends_with_any(self, line: str) -> bool:
        """
        Heuristic: The line ends with any of the 'line_endings' tokens, e.g. ";", "})", etc.
        """
        trimmed = line.strip()
        return any(trimmed.endswith(ending) for ending in self.line_endings)

    def is_good_place(self, line: str) -> bool:
        """
        Decide if this line is a "good place" to insert a comment,
        based on combining multiple heuristics.

        We can make it "OR" logic: if any of these returns True -> return True.
        Or we can get more fancy: define an order or weighting, etc.
        """
        # Example "OR" logic:

        # 1) If blank lines are allowed and the line is blank
        if self.allow_blank_lines and self.is_blank_line(line):
            return True

        # 2) If the line ends with any of our "completing tokens" (like semicolon)
        if self.ends_with_any(line):
            return True

        return False


def insert_comment_after_pattern(
    lines, pattern, comment_block, heuristics: InsertionHeuristics
) -> Tuple[List[str], int]:
    """
    Find occurrences of 'pattern' in lines, then look for a line *after*
    we detect the pattern that satisfies 'heuristics.is_good_place(...)'.
    Insert the comment there.

    :param lines: list of lines from the file.
    :param pattern: the string/regex pattern to search for.
    :param comment_block: the block comment string to insert.
    :param heuristics: an instance of InsertionHeuristics (or similar).
    :return: a tuple: list of updated lines, insertion index
    """
    output = []
    # If you want to handle regex, compile it here. For simplicity:
    regex = re.compile(r"\b" + re.escape(pattern) + r"\b")
    insert_index = 0

    # We'll track whether we've just found the pattern
    # and are hunting for the next "good place" to insert the comment.
    found_pattern = False

    for i, line in enumerate(lines):
        output.append(line)

        # If we previously found the pattern but haven't inserted yet,
        # check if this line is a "good place."
        if found_pattern:
            if heuristics.is_good_place(line):
                # Insert the comment on the line *just before* this line
                # or just after, depending on style. Let's do before for example:
                # We'll insert it at the index of the newly appended line minus 1
                insert_index = len(output) - 1
                output.insert(insert_index, comment_block + "\n")
                found_pattern = False
                # If you want to insert after the line, you can do it differently:
                # output.append(comment_block + "\n")

        # Check if current line has the pattern
        if regex.search(line):
            found_pattern = True

    # If we reach the end and still haven't inserted the comment,
    # maybe insert at the very end?
    if found_pattern:
        insert_index = len(lines) - 1
        output.append(comment_block + "\n")

    return output, insert_index


def split_at[T](values: list[T], indices: list[int]) -> tuple[list[T], ...]:
    """
    Split a list into sublists at the specified indices.
    Since files are easily turned into rows this works well as a
    tool slice and recombine text context in files.

    :param values: The list to split
    :param indices: List of indices where to split
    :return: Tuple of sublists
    """
    if not indices:
        return (values,)

    result = []
    sorted_indices = sorted(set(i for i in indices if 0 <= i < len(values)))

    # Print warnings for invalid indices
    for i in indices:
        if i < 0 or i >= len(values):
            print(f"Warning: Index {i} is out of range")

    # Handle first segment
    start = 0
    if sorted_indices and sorted_indices[0] == 0:
        result.append([])
        start = sorted_indices[0]
        sorted_indices = sorted_indices[1:]

    # Split at each index
    for i in sorted_indices:
        result.append(values[start:i])
        start = i

    # Add remaining elements
    result.append(values[start:])

    return tuple(result)


def find_insertion_points(
    lines: list[str], pattern: str, heuristics: InsertionHeuristics
) -> tuple[list[int], list[str]]:
    """
    Find suitable insertion points for comments based on pattern matching and heuristics.

    :param lines: List of lines to analyze
    :param pattern: Pattern to search for
    :param heuristics: Heuristics for determining good insertion points
    :return: Tuple of (insertion points, warnings)
    """
    # Step 1: Build the boolean map and find pattern matches
    good_places = [heuristics.is_good_place(line) for line in lines]
    regex = regexp_utils.compile(pattern)
    pattern_indices = [i for i, line in enumerate(lines) if regex.search(line)]

    # Step 2: Find best insertion points
    insertion_points = []
    warnings = []

    for idx in pattern_indices:
        current = idx
        found = False

        # Look backwards for a good insertion point
        while current >= 0:
            if good_places[current]:
                insertion_points.append(current)
                found = True
                break
            current -= 1

        if not found:
            warnings.append(
                f"No suitable insertion point found before pattern at line {idx + 1}"
            )

    return insertion_points, warnings


# def insert_comments(
#         lines: list[str], insertion_points: list[int], comment: str
# ) -> list[str]:
#     """
#     Insert comments at the specified points.
#
#     :param lines: Original lines
#     :param insertion_points: Where to insert comments
#     :param comment: The comment to insert
#     :return: Modified lines
#     """
#     result = lines.copy()
#     # Sort in reverse to avoid shifting indices
#     for idx in sorted(insertion_points, reverse=True):
#         result.insert(idx, comment + "\n")
#     return result
#
#
# def insert_comment_after_pattern(
#         lines: list[str], pattern: str, comment_block: str, heuristics: InsertionHeuristics
# ) -> tuple[list[str], int]:
#     """
#     Find and insert comments using the new two-step approach.
#
#     :param lines: List of lines to process
#     :param pattern: Pattern to search for
#     :param comment_block: Comment to insert
#     :param heuristics: Heuristics for determining insertion points
#     :return: Tuple of (modified lines, last insertion point)
#     """
#     insertion_points, warnings = find_insertion_points(lines, pattern, heuristics)
#
#     # Print warnings
#     for warning in warnings:
#         print(f"Warning: {warning}")
#
#     result = insert_comments(lines, insertion_points, comment_block)
#     last_index = insertion_points[-1] if insertion_points else len(lines) - 1
#
#     return result, last_index
