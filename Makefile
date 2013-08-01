#!/usr/bin/make

all: html/index.html

html/index.html: talk.xml mkpres.pl _slide.html _toc.html _notes.html _index.html
	./mkpres.pl

clean:
	rm -f html/*.html
	rm -f html/*.txt

deploy: external internal

internal: all
	scp -r html/* boole.wgtn.cat-it.co.nz:/general/catalyst/Resources/Slides/git/

external: all
	scp -r html/* socrates.catalyst.net.nz:public_html/
