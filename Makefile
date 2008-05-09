#!/usr/bin/make

html/index.html: talk.xml
	./mkpres.pl
