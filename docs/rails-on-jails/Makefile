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
	chapters/08-catalog-api.tex \
	chapters/09-store-jail.tex \
	chapters/10-store-toolchain.tex \
	chapters/11-store-application.tex \
	chapters/12-store-database.tex \
	chapters/13-store-catalog-client.tex \
	chapters/14-live-integration-test.tex \
	chapters/15-web-jail.tex \
	chapters/16-web-proxy.tex \
	chapters/17-publish-web.tex \
	chapters/18-catalog-service.tex \
	chapters/19-store-service.tex \
	chapters/20-service-graph.tex \
	chapters/21-test-jail.tex \
	chapters/22-black-box-test.tex \
	chapters/23-failure-injection.tex \
	chapters/24-host-test-command.tex \
	chapters/25-owned-test-fixture.tex \
	chapters/26-host-exit-status.tex \
	chapters/27-conclusion.tex

.PHONY: all pdf clean

all: pdf

pdf: $(PDF)

$(PDF): $(MAIN) $(CHAPTERS)
	mkdir -p $(BUILD_DIR)
	$(LATEXMK) -pdf -interaction=nonstopmode -halt-on-error \
		-outdir=$(BUILD_DIR) $(MAIN)

clean:
	$(LATEXMK) -C -outdir=$(BUILD_DIR) $(MAIN)
