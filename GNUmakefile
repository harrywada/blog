POSTS = $(filter-out meta.rss.part,$(wildcard *.rss.part))
PAGES = $(patsubst %.rss.part,%.html,$(POSTS))

.PHONY: clean default
default: $(PAGES) index.html feed.rss
clean:
	rm $(PAGES) index.html feed.rss

feed.rss: $(POSTS) meta.rss.part
	{ printf '<rss version="2.0">\n<channel>\n' ;\
	  cat $^ ;\
	  printf '</channel>\n</rss>\n' ;\
	} | sed s/^[\ \\t]\\+// >feed.rss

index.html: feed.rss
	sh mkindex.sh feed.rss >index.html

.SUFFIXES: .rss.part .html
.rss.part.html:
	sh mkpage.sh $< >$@
