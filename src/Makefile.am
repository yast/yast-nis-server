#
# Makefile.am for modules/y2c_nis_server/src
#

menudir = $(YAST2DIR)/menuentries
modulesdir = $(YAST2DIR)/clients
includedir = $(YAST2DIR)/include/nis_server
bindir = $(YAST2DIR)/bin

include_DATA = \
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

menu_DATA = menuentry_nis_server.ycp

EXTRA_DIST = \
	$(modules_DATA) \
	$(menu_DATA) 	\
	$(include_DATA)