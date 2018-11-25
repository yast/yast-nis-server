# Sources for nis-server

module_DATA = \
  modules/NisServer.rb

client_DATA = \
  clients/nis_server_auto.rb \
  clients/nis_server.rb \
  clients/nis-server.rb

yncludedir = @yncludedir@/nis_server
ynclude_DATA = \
  include/nis_server/what.rb \
  include/nis_server/wizards.rb \
  include/nis_server/slaves.rb \
  include/nis_server/securenets.rb \
  include/nis_server/ui.rb \
  include/nis_server/maps.rb \
  include/nis_server/master.rb \
  include/nis_server/routines.rb \
  include/nis_server/slave.rb \
  include/nis_server/details.rb

scrconf_DATA = \
  scrconf/var_yp_securenets.scr \
  scrconf/var_yp_ypservers.scr \
  scrconf/run_ypwhich_m.scr

schemafilesdir = $(schemadir)/autoyast/rnc
schemafiles_DATA = \
  autoyast-rnc/nis_server.rnc

desktop_DATA = \
  desktop/nis_server.desktop

scalabledir = @icondir@/hicolor/scalable/apps
scalable_DATA =\
  icons/hicolor/scalable/apps/yast-nis-server.svg

EXTRA_DIST = $(module_DATA) $(client_DATA) $(ynclude_DATA) $(scrconf_DATA) $(schemafiles_DATA) $(desktop_DATA) $(scalable_DATA)

include $(top_srcdir)/Makefile.am.common
