#!/bin/bash
FILENAME="report.tex"

doLaTeX() {
    pdflatex -file-line-error -interaction=nonstopmode -shell-escape "${1}" | grep -i ".*:[0-9]*:.*\|warning\|badness\|full"
    if [ ${PIPESTATUS[0]} -ne 0 ]
    then
        exit 1
    fi
    echo
}

doBibTeX() {
    bibtex -terse "${1%.tex}.aux" | grep -iv "^--\|^$"
    echo
}

DIRNAME="$(dirname "$(readlink -f "${0}")")"
FULLFILENAME="${DIRNAME}/${FILENAME}"
cd "${DIRNAME}"
doLaTeX "${FULLFILENAME}"
doBibTeX "${FILENAME}"
doLaTeX "${FULLFILENAME}"
doLaTeX "${FULLFILENAME}"
exit 0
