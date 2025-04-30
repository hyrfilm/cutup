import os
from pathlib import Path

from library import *

base_iter = [
    f"A simple yatzy score calculator in the form of a single html-page."
    f"The game should allow you to enter a name of a player, and press a button for adding a player."
    f"The scores should be represented in a similar way to how it's done on paper, "
    f"like a spreadsheet where each player occupies horizontal columns while",
    f"the list of possible scores are selected with buttons vertcially",
    f"clicking on a one of the score buttons (1,2,3,4,5,6) registers a score for that player.",
    f"Below are buttons for registering pairs, house, flush etc. To register a score you press that player, and register scores."
    f"Scores are always up to date. ",
    f"There is a button for starting a new round."
    f"The bottom cells presents the sum for each player, just like in a spreadsheet."
    f"The state of the current game should be stored in localStorage so it's always possible to resume it."
    f"Every time the state of the game changes it is appended to an array. Undo & redo buttons moves back and forth in this array."
    ]

language_iter = [
    f"The UI language should be Swedish."
]

mobile_iter = [
    f"The UX should be adapted for a mobile display."
]

title_iter = [
    f"The title should be Ljusterö Yatzy Vibe 😂🍷😭"
]

all_iterations = [base_iter, language_iter, mobile_iter, title_iter]

for i, iteration in enumerate(all_iterations):
    in_html = 'index_v%d.html' % (i-1)
    in_js = 'index_v%d.js' % (i-1)
    in_css = 'index_v%d.css' % (i-1)

    out_html = 'index_v%d.html' % i
    out_js = 'index_v%d.js' % i
    out_css = 'index_v%d.css' % i

    touch(out_html)
    touch(out_js)
    touch(out_css)

    if i == 0:
        pre = [f"Your task is create the following: "]
    else:
        pre = [f"First read these files: path://{in_html} path://{in_js} path://{in_css} "]

    post = [f" Write the result to these files: path://{out_html} path://{out_js} path://{out_css} "]

    instructions = [*pre, *iteration, *post]
    prompt(instructions)
