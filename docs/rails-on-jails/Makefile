LATEXMK ?= latexmk
MAIN := main.tex
BUILD_DIR := build
PDF := $(BUILD_DIR)/main.pdf
CHAPTERS := chapters/01-introduction.tex \
	chapters/02-inventory.tex \
	chapters/03-database-jail.tex \
	chapters/04-database-client.tex \
	chapters/05-catalog-toolchain.tex \
	chapters/06-catalog-application.tex \
	chapters/07-catalog-database.tex \
	chapters/08-catalog-api.tex

.PHONY: all pdf clean

all: pdf

pdf: $(PDF)

$(PDF): $(MAIN) $(CHAPTERS)
	mkdir -p $(BUILD_DIR)
	$(LATEXMK) -pdf -interaction=nonstopmode -halt-on-error \
		-outdir=$(BUILD_DIR) $(MAIN)

clean:
	$(LATEXMK) -C -outdir=$(BUILD_DIR) $(MAIN)
