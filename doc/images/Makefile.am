#
# Makefile.am for nis-server/doc/images
#

htmldir = $(docdir)/images

screenshots = \
	0-load.png \
	1-which.png \
	2-master.png \
	2-slave.png \
	21-details.png \
	3-slaves.png \
	31-edit.png \
	4-maps.png \
	5-nets.png \
	51-edit.png \
	6-saving.png \
	abort.png \
	error-details.png \
	error.png \
	exit.png \
	finish.png \
	reboot.png \
	success.png

workflow.jpg: workflow.dia $(screenshots)
	dia --export=workflow.png $<
	convert -quality 50 workflow.png $@
	-$(RM) workflow.png
MAINTAINERCLEANFILES = workflow.jpg

html_DATA = workflow.dia workflow.jpg $(screenshots)
EXTRA_DIST = $(html_DATA)
