#
# Makefile.am for nis-server/doc/images
#

htmldir = $(docdir)/images

screenshots = \
	0-load.jpg \
	1-which.jpg \
	2-master.jpg \
	2-slave.jpg \
	21-details.jpg \
	3-slaves.jpg \
	31-edit.png \
	4-maps.jpg \
	5-nets.jpg \
	51-edit.png \
	6-saving.jpg \
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
