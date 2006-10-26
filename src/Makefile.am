# Makefile.am for source/nis-server/src

myincludedir = @yncludedir@/nis_server

rncdir =  $(schemadir)/autoyast/rnc

myinclude_DATA =	\
	what.ycp 	\
	slave.ycp 	\
	master.ycp 	\
	details.ycp	\
	slaves.ycp	\
	maps.ycp	\
	securenets.ycp 	\
	wizards.ycp	\
	ui.ycp		\
	routines.ycp

module_DATA = NisServer.ycp

client_DATA = 		\
	nis-server.ycp	\
	nis_server.ycp	\
	nis_server_auto.ycp

desktop_DATA = nis_server.desktop

rnc_DATA = nis_server.rnc

EXTRA_DIST =		\
	$(module_DATA)	\
	$(client_DATA)	\
        $(desktop_DATA)	\
	$(myinclude_DATA) $(rnc_DATA)

nis_server:
	ln -sf . nis_server

ycpchook = nis_server

YCPCFLAGS=-I.

include $(top_srcdir)/Makefile.am.common
