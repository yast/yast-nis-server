#
# Makefile.am for modules/y2c_nis_server/src
#

menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/clients
yincludedir = $(YAST2DIR)/include/nis_server
bindir = $(YAST2DIR)/bin

yinclude_DATA = \
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

modules_DATA = 	\
	nis_server.ycp

menu_DATA = menuentry_nis_server.y2cc

EXTRA_DIST = \
	$(modules_DATA) \
	$(menu_DATA) 	\
	$(yinclude_DATA)
