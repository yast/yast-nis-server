#
# Makefile.am for nis-server/src
#

myincludedir = @yncludedir@/nis_server

myinclude_DATA = \
	what.ycp 	\
	slave.ycp 	\
	master.ycp 	\
	details.ycp	\
	slaves.ycp	\
	maps.ycp	\
	securenets.ycp 	\
	io.ycp		\
	ui.ycp		\
	routines.ycp

client_DATA = 	\
	nis_server.ycp

config_DATA = nis_server.y2cc

EXTRA_DIST = \
	$(module_DATA) \
	$(config_DATA) 	\
	$(myinclude_DATA)
