# NCSA Software

Two pieces of software from the National Center for Supercomputing Applications
at the University of Illinois Urbana-Champaign. NCSA was ground zero for the
early web — they wrote both the server and the browser that most people first
used to get on it.

## httpd 1.3

`httpd/httpd_1.3.tar.gz`

NCSA HTTPd was the dominant web server of the early 1990s. Version 1.3 is from
1994, right at the peak of its use. This is a source distribution — it needs
to be compiled on the target machine.

This is also where Apache came from. In 1995 a group of webmasters started
sharing patches for HTTPd, eventually collected them into what they called "a
patchy server", and Apache was born. HTTPd itself stopped being developed
shortly after. If you ran a website in 1994 you were almost certainly running
this.

The archive extracts to `httpd_1.3/`. The original online documentation
referenced in the README is long gone, but the config files and source are
reasonably self-explanatory. Default port is 80, document root and config
location are set in `conf/httpd.conf`.

## Mosaic 2.4

`mosaic/Mosaic-2.4.bin.tar.gz`

NCSA Mosaic was the first graphical web browser most people ever used. Marc
Andreessen and Eric Bina wrote it at NCSA and released it in 1993. Version 2.4
is from 1994. Before Mosaic, the web was mostly text terminals and gopher.
Mosaic is what turned it into something normal people could actually use.

This is a pre-compiled Linux binary distribution — no build required. The
archive extracts to `Mosaic-2.4/` with the `Mosaic` executable ready to run.
It requires X11 and Motif (or a Motif-compatible library like lesstif) to be
installed on the target system.

The `app-defaults.color` file should be copied to your X11 app-defaults
directory (typically `/usr/lib/X11/app-defaults/Mosaic`) for correct color
and font settings.

Andreessen left NCSA in 1994 to co-found Netscape. Mosaic was effectively
abandoned shortly after. The lineage from Mosaic → Netscape Navigator →
Mozilla → Firefox is a straight line.
