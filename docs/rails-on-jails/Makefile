LATEXMK ?= latexmk
MAIN := main.tex
BUILD_DIR := build
PDF := $(BUILD_DIR)/main.pdf
CHAPTERS := chapters/01-introduction.tex

.PHONY: all pdf clean

all: pdf

pdf: $(PDF)

$(PDF): $(MAIN) $(CHAPTERS)
	mkdir -p $(BUILD_DIR)
	$(LATEXMK) -pdf -interaction=nonstopmode -halt-on-error \
		-outdir=$(BUILD_DIR) $(MAIN)

clean:
	$(LATEXMK) -C -outdir=$(BUILD_DIR) $(MAIN)
