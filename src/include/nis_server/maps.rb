# encoding: utf-8

# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

#
# File:
#   maps.ycp
#
# Module:
#   Network/YPServer
#
# Summary:
#   YPServer module.
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# YPServer module part.
#
module Yast
  module NisServerMapsInclude
    def initialize_nis_server_maps(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "Wizard"
      Yast.import "Popup"

      Yast.import "NisServer"
      Yast.include include_target, "nis_server/routines.rb"
    end

    # Maps dialog
    # @return `back, `abort or `next
    def MapsDialog
      # help text 1/1
      # Translators: the text was truncated because now there's
      # a MultiSelectionBox instead of two SelectionBoxes that
      # were a pain to use.
      helptext = _(
        "<p>With this dialog, adjust which maps will be available.</p>"
      )

      # Let's call a yp map a table, not to get too confused.

      # All tables that ypserv Makefile knows about
      all = NisServer.GetAllMaps

      # Assign a source file to all tables.
      # Some tables are built of more files while we only check for one.
      # Still it's better than no checking at all.
      passwd_tables = ["passwd", "group", "passwd.adjunct", "shadow"]
      passwd_dir = NisServer.pwd_srcdir
      files = Builtins.listmap(all) do |table|
        { table => Builtins.sformat("/etc/%1", table) }
      end
      Builtins.foreach(passwd_tables) do |table|
        Ops.set(files, table, Builtins.sformat("%1/%2", passwd_dir, table))
      end
      # irregularly named tables
      Ops.set(files, "netgrp", "/etc/netgroup")
      Ops.set(files, "mail", "/etc/mail/aliases")

      # We want to construct a list of items:
      # `item (`id (table), table, true|false)
      enabled = Builtins.listmap(all) { |table| { table => false } }
      # filter out tables that are merged or their sources don't exist
      enabled = Builtins.remove(enabled, "shadow") if NisServer.merge_passwd
      enabled = Builtins.filter(enabled) do |table, dummy|
        Ops.greater_or_equal(
          SCR.Read(path(".target.size"), Ops.get_string(files, table, "/")),
          0
        )
      end
      current = deep_copy(NisServer.maps)
      Builtins.foreach(current) { |table| Ops.set(enabled, table, true) }
      items = Builtins.maplist(enabled) { |table, e| Item(Id(table), table, e) }

      contents = MultiSelectionBox(
        # multilesection box label
        Id(:current),
        _("&Maps"),
        items
      )

      # To translators: dialog label
      Wizard.SetContents(
        _("NIS Server Maps Setup"),
        contents,
        helptext,
        true,
        true
      )

      ui = nil
      begin
        ui = Convert.to_symbol(UI.UserInput)
        ui = :abort if ui == :cancel

        ui = :again if ui == :abort && !Popup.ReallyAbort(NisServer.modified)
      end until Builtins.contains([:back, :next, :abort], ui)

      current = Convert.convert(
        UI.QueryWidget(Id(:current), :SelectedItems),
        :from => "any",
        :to   => "list <string>"
      )
      if ui == :next && Builtins.sort(current) != Builtins.sort(NisServer.maps)
        NisServer.maps = deep_copy(current)
        NisServer.modified = true
      end
      ui
    end
  end
end
