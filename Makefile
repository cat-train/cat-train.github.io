#!/usr/bin/make

deploy: external internal

internal:
	scp -r * boole.wgtn.cat-it.co.nz:/general/catalyst/Resources/Slides/git/

external:
	scp -r * socrates.catalyst.net.nz:public_html/g2/
