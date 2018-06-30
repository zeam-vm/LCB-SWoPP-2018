PDF = manuscript.pdf

all: ${PDF}

%.pdf:  %.tex ipsj.cls description.tex ipsjsort.bst reference.bib Makefile memory-callback-process.xbb
	ptex2pdf -e -l -ot '-synctex=1' -od '-f ptex-ipaex.map' $<
	- pbibtex $*
	ptex2pdf -e -l -ot '-synctex=1' -od '-f ptex-ipaex.map' $<
	ptex2pdf -e -l -ot '-synctex=1' -od '-f ptex-ipaex.map' $<
	while ( grep -q '^LaTeX Warning: Label(s) may have changed' $*.log) \
	do ptex2pdf -e -l -ot '-synctex=1' -od '-f ptex-ipaex.map' $<; done
	# dvipdfmx $*

description.tex: description.md
	@cat $^ \
	| pandoc -f markdown -t latex -V documentclass=ltjarticle --pdf-engine=lualatex -f markdown-auto_identifiers \
	| sed 's/includegraphics/includegraphics[width=1.0\\columnwidth]/g' \
	| sed 's/includegraphicS/includegraphics/g' \
	| sed 's/\[htbp\]/\[t\]/g' \
	> description.tex

memory-callback-process.xbb: memory-callback-process.png
	extractbb $<

clean:
	@rm -rf description.{dvi,log,tex} manuscript.{pdf,aux,dvi,log,out,blg,bbl,.synctex.gz} *.xbb
