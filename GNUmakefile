POSTS = $(wildcard articles/*.html)
ASSETS = $(wildcard assets/*)
PAGES = $(notdir $(POSTS)) index.html index.css feed.xml COPYING
PUBLIC := $(addprefix public/,$(PAGES) $(ASSETS))

RESOURCES = $$(wildcard resources/$$*_*)

include info.mk

.PHONY: clean compose default publish

default: $(PUBLIC)
clean:
	rm -rf public/ index.html feed.xml

compose: draft.html
	$(EDITOR) draft.html
publish:
	sh publish.sh draft.html articles/

draft.html:
	cp starter.html draft.html

index.html: $(POSTS) info.mk
	export TITLE=$(TITLE) URI=$(URI) DESCRIPTION=$(DESCRIPTION); \
	sh index.sh $(filter %.html,$^) >index.html
feed.xml: $(POSTS) info.mk
	export TITLE=$(TITLE) URI=$(URI) DESCRIPTION=$(DESCRIPTION); \
	sh rss.sh $(filter %.html,$^) >feed.xml

public/:
	mkdir -p public/
.SECONDEXPANSION:
public/%.html: articles/%.html $(RESOURCES) header.html footer.html | public/
	sh assemble.sh $< header.html footer.html >$@
public/%: %
	@ mkdir -p $(@D)
	cp $< $@
