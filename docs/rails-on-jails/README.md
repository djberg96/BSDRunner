# Rails on Jails

This directory contains the source for *Rails on Jails: End-to-End Testing on
FreeBSD*. The tutorial is written as a small LaTeX book, with one source file
per chapter under `chapters/`.

## Build the PDF

On a system with `latexmk` and `pdflatex` installed:

```sh
make
```

The generated handbook is `build/main.pdf`. Build artifacts are intentionally
not committed.

To remove generated LaTeX files:

```sh
make clean
```

## Tutorial approach

The tutorial grows along with the working system. Each chapter introduces one
small concept, asks the reader to complete an exercise, and gives an observable
result to check before continuing. Later chapters will be added only as the
corresponding part of the jail environment is built and verified.
