# Makefile.am for source/nis-server/src

myincludedir = @yncludedir@/nis_server

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

config_DATA = nis_server.y2cc

desktop_DATA = nis_server.desktop

EXTRA_DIST =		\
	$(module_DATA)	\
	$(client_DATA)	\
	$(config_DATA)	\
        $(desktop_DATA)	\
	$(myinclude_DATA)

include $(top_srcdir)/Makefile.am.common
