### CutUp
Imagine if grep would marry awk but then grep would have an affair with sed - they would divorce and to make matters worse that asshole grep would end up with a huge divorce settlement... 
Fast forward a few years and grep is now a fullblown champagne alcoholic that occasionally smokes meth (on special occasions). Fast forward some more years and grep is now in AA and a born-again christian. Grep and AWK meet randomly at a silent retreat and rekindles their friendship as they both developed an interest in Spirituality especially instagram-stories from this old wise lady that creates these christals that represents your primeordial trauma. Anyway, soon their friendship blossoms into an even stronger version of their previous love. They marry again, and not long after they have their first child: an LLM. And then they died. The whole family. No of course not, they lived forevever happy or forever or something. It's not that important.

So in what way is this appropriate metaphore to describe what CutUp is? WHO CARES! 

### TL;DR
But I suppose it's vaguely connected to it in the sense that it's a collection Unixy text/search/match/download tools paired with an LLM agent. It was mainly developed for doing really big, sweeping refactorings across a project that you can't do in an IDE, because they are not mechanical in a way to make feasible. But I've found it useful for surprisingly diverse tasks, eg linting, scanning for bugs and potential security issues. The basic workflow is usually hacking together some throwaway script, iterating until it feels close enough to what you needed.

### example scripts

There are some examples in the aptly named directory 'examples':
1) one of them takes fairly large postgres dump and creates TypeScript entity interfaces
2) the other one downloads the lodash docs, converts it to markdown and writes a new reference where each function also gets described as implemented using the standard JS library, from the trivial ones like filter to ones that require more effort (like using reduce to implement _.chunk, not one of humankinds crowning achievements) and so on for every function in the library.
3) clones a python 2 repo and migrates it to python 3
