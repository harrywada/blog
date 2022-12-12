POSTS = $(wildcard articles/*.html)
ASSETS = $(wildcard assets/*)
PAGES = $(notdir $(POSTS)) index.html index.css feed.xml COPYING
PUBLIC := $(addprefix public/,$(PAGES) $(ASSETS))

RESOURCES = $$(wildcard resources/$$*_*)

.PHONY: clean compose default publish

default: $(PUBLIC)
clean:
	rm -rf public/

compose: draft.html
	$(EDITOR) draft.html
publish:
	sh publish.sh draft.html articles/

draft.html:
	cp templates/starter.html draft.html

public/:
	mkdir -p public/
public/index.html public/feed.xml: $(POSTS) templates/$(@F) | public/
	./template.sh templates/$(@F) >$@
.SECONDEXPANSION:
public/%.html: articles/%.html templates/header.html templates/footer.html \
               $(RESOURCES) | public/
	./template.sh $< templates/header.html templates/footer.html >$@
public/%: %
	@ mkdir -p $(@D)
	cp $< $@
