#!/usr/bin/make

all: html/index.html

html/index.html: talk.xml
	./mkpres.pl

clean:
	rm -f html/*.html
	rm -f html/*.txt
