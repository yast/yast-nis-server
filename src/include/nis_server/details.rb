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
#   details.ycp
#
# Module:
#   Network/YPServer
#
# Summary:
#   YPServer module.
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#
# $Id$
#
# YPServer module part.
#
module Yast
  module NisServerDetailsInclude
    def initialize_nis_server_details(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "Label"
      Yast.import "Message"
      Yast.import "Mode"
      Yast.import "NisServer"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "nis_server/routines.rb"
    end

    # Details dialog
    # @return `back, `abort or `next
    def DetailsDialog
      srcdir = NisServer.pwd_srcdir

      minuid = NisServer.minuid
      mingid = NisServer.mingid
      merge_passwd = NisServer.merge_passwd

      # help text 1/3
      helptext = _(
        "<p>You can change NIS server source directory (usually\n<i>'/etc'</i>).</p>"
      )

      # help text 2/3
      helptext = Ops.add(
        helptext,
        _(
          "<p>Select if your <i>passwd</i> file should be merged with the <i>shadow</i>\nfile (only possible if the <i>shadow</i> file exists).</p>\n"
        )
      )

      # help text 3/3
      helptext = Ops.add(
        helptext,
        _("<p>You can also adjust the minimum user and group id.</p>")
      )

      minimals = HBox(
        # To translators: intfield label
        IntField(Id(:minuid), _("Minimum &UID"), 0, 50000, minuid),
        HSpacing(),
        # To translators: intfield label
        IntField(Id(:mingid), _("Minimum &GID"), 0, 50000, mingid)
      )

      contents = HVSquash(
        VBox(
          InputField(
            Id(:srcdir),
            Opt(:notify, :hstretch),
            # To translators: textentry label
            _("&YP Source directory"),
            srcdir
          ),
          VSpacing(0.5),
          # check box label
          Left(CheckBox(Id(:merge_passwd), _("Merge pa&sswords"), merge_passwd)),
          VSpacing(0.5),
          minimals
        )
      )

      # To translators: dialog label
      Wizard.SetContents(
        _("NIS Master Server Details Setup"),
        contents,
        helptext,
        true,
        true
      )

      Wizard.SetBackButton(:back, Label.CancelButton)
      Wizard.SetNextButton(:next, Label.OKButton)
      Wizard.HideAbortButton

      # If the source directory does not exist, it will be created
      # with empty passwd, group, shadow
      # If it already exists, check whether shadow exist
      # and disable some options accordingly.
      # (#15624)
      srcdir_exists = nil
      shadow_exists = nil
      change_enabled = true

      ui = :again
      begin
        if change_enabled
          # srcdir now has an up-to-date value
          srcdir_exists = SCR.Read(path(".target.dir"), srcdir) != nil
          shadow_exists = !srcdir_exists ||
            SCR.Read(
              path(".target.size"),
              Builtins.sformat("%1/shadow", srcdir)
            ) != -1
          UI.ChangeWidget(Id(:merge_passwd), :Enabled, shadow_exists)
        end

        ui = Convert.to_symbol(UI.UserInput)
        ui = :abort if ui == :cancel

        change_enabled = ui == :srcdir
        srcdir = Convert.to_string(UI.QueryWidget(Id(:srcdir), :Value))
        ui = :again if ui == :abort && !Popup.ReallyAbort(NisServer.modified)
        if ui == :next
          if SCR.Read(path(".target.dir"), srcdir) == nil && !Mode.config
            UI.SetFocus(Id(:srcdir))
            ui = Popup.YesNo(Message.DirectoryDoesNotExistCreate(srcdir)) ? :next : :again
          end
          merge_passwd = Convert.to_boolean(
            UI.QueryWidget(Id(:merge_passwd), :Value)
          )
          minuid = Convert.to_integer(UI.QueryWidget(Id(:minuid), :Value))
          mingid = Convert.to_integer(UI.QueryWidget(Id(:mingid), :Value))
          if NisServer.minuid != minuid || NisServer.mingid != mingid ||
              NisServer.merge_passwd != merge_passwd ||
              NisServer.pwd_srcdir != srcdir
            NisServer.modified = true
            NisServer.minuid = minuid
            NisServer.mingid = mingid
            NisServer.merge_passwd = merge_passwd
            NisServer.pwd_srcdir = srcdir
          end
        end
      end until Builtins.contains([:back, :next, :abort], ui)

      Wizard.RestoreBackButton
      Wizard.RestoreNextButton
      Wizard.RestoreAbortButton
      ui
    end
  end
end
