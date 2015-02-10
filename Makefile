#!/usr/bin/make

deploy: external internal

internal:
	scp index.html boole.wgtn.cat-it.co.nz:/general/catalyst/Resources/Slides/git/
	scp -r * boole.wgtn.cat-it.co.nz:/general/catalyst/Resources/Slides/git/

external:
	scp index.html socrates.catalyst.net.nz:public_html/
	scp -r * socrates.catalyst.net.nz:public_html/
