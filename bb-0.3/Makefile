CFLAGS	= -Wall -g `xml2-config --cflags --libs` `xslt-config --cflags --libs`

bb: bb.o
	$(CC) $(CFLAGS) -o $(@) $(<)

bb.exe: bb.c
	i486-mingw32-gcc -Wall -g -o $(@) $(<) -DWINDOWS \
		-llibxml2 -llibxslt -lwsock32

clean:
	rm -f *.o bb

dist: bb bb.exe
	rm -fr dist
	mkdir -p dist/linux/bb-`./bb -v`
	mkdir -p dist/win/bb-`./bb -v`
	cp README ChangeLog Makefile *.c *.xsl dist/linux/bb-`./bb -v`
	tar zcvf dist/bb-`./bb -v`.tgz -C dist/linux bb-`./bb -v`
	cp dist/linux/bb-`./bb -v`/* dist/win/bb-`./bb -v`/
	cp *.dll *.exe dist/win/bb-`./bb -v`/
	cd dist/win && zip -r ../bb-`../../bb -v`.zip bb-`../../bb -v`

.PHONY: dist
