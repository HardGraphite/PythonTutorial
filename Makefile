PANDOC ?= pandoc
PANDOC_MD_TO_HTML_FLAGS = -f markdown -t html --standalone --number-sections

BUILD_DIR ?= build

CHAPTER_DIR = chapters
CHAPTER_MDS = $(wildcard ${CHAPTER_DIR}/*.md)
CHAPTER_HTMLS = $(patsubst ${CHAPTER_DIR}/%.md,${BUILD_DIR}/%.html,${CHAPTER_MDS})

all: html

html: ${BUILD_DIR} ${CHAPTER_HTMLS}

${BUILD_DIR}:
	[ -d "$@" ] || mkdir "$@"

${BUILD_DIR}/%.html: ${CHAPTER_DIR}/%.md
	${PANDOC} ${PANDOC_MD_TO_HTML_FLAGS} \
		--metadata title="$(patsubst ${CHAPTER_DIR}/%.md,%,$<)" \
		$< -o $@

.PHONY: clean
clean:
	rm ${CHAPTER_HTMLS}
