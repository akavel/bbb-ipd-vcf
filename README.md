bbb-ipd-vcf
===========

Quick &amp; dirty scripts to convert Address Book (Contacts list) from
BlackBerry .bbb/.ipd backup (BB Desktop Software 7.1) to
vCard .vcf files (for Android &amp; other civilized phones).


Procedure
---------

1. Install Lua (http://lua.org) and Go (http://golang.org).
2. Rename `BlackBerry Bold 9780 (08-12-2013).bbb` to `backup.zip`.
3. Unpack `backup.zip`.
4. In file `Manifest.xml`, find fragment like this: `<Database uid="125" recordcount="509">Address Book - All</Database>`, then note the `uid` value (here: 125).
5. Find `uid` .dat file, e.g. `Databases\125.dat` (this is actually an .ipd formatted file).
6. Run: `lua ipd2xml.lua 125.dat | go run xml2vcf.go > contacts.vcf`.

Worked For Me&trade;...

License
-------

Unless otherwise noted, MIT/X11.

Bibliography
------------

* IPD format:
  * http://darkircop.org/bb - "Blackberry IPD and service book editor" by <a.bittau@cs.ucl.ac.uk>, with C source code
  * https://code.google.com/p/bbipd - some draft docs on the format
  * http://code.google.com/p/ipddump - by <jimdakalakis01 gmail.com>, Java source code, New BSD license
  * I seem to recall that there were some rough docs on BB website, but don't remember where as of now.
  * (possibly useful: https://sites.google.com/site/ipdparse/faq - ?? but not tested/verified by me)
  * lot's of fun with a hex editor.
* thanks to Laurent Le Goff for https://bitbucket.org/llg/vcard

Cheers,  
[/Mateusz Czapliński.](http://akavel.com)
