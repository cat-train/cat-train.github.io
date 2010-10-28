#!/usr/bin/make

all: html/index.html

html/index.html: talk.xml mkpres.pl _slide.html _toc.html _notes.html _index.html
	./mkpres.pl

clean:
	rm -f html/*.html
	rm -f html/*.txt
