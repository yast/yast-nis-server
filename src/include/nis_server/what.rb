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
#   what.ycp
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
  module NisServerWhatInclude
    def initialize_nis_server_what(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "NisServer"
      Yast.include include_target, "nis_server/routines.rb"
    end

    # Dialog for choosing the way of the flow
    # @return `abort, `exit, `nothing, `master, `slave or `finish
    def WhatToConfigure
      # help text 1/2
      helptext = _(
        "<p>Select whether to configure the NIS server as a <b>master</b> or a\n<b>slave</b> or not to configure a NIS server.</p>\n"
      )

      detected = NisServer.ui_what
      labels = VBox()
      labels = Builtins.add(labels, VSpacing(1.5))

      if NisServer.isYPServerInstalled
        # To translators: label in the dialog
        install_label = _("NIS Software is installed.")
      else
        # help text 2/2
        helptext +=
          _(
            "<p>The NIS server package will be <b>installed</b> first if you want to\nconfigure it.</p>"
          )
        # To translators: label in the dialog
        install_label = _("No NIS Software is installed.")
      end
      labels << Left(Label(install_label))

      if detected == :none
        # To translators: label in the dialog
        labels << Left(Label(_("No NIS Server is configured.")))

        # To translators: label in the dialog
        master_setup_label = _("Install and set up an NIS &Master Server")
        # To translators: label in the dialog
        slave_setup_label = _("Install and set up an NIS &Slave Server")
        # To translators: label in the dialog
        none_setup_label = _("&Do nothing and leave set up")
      elsif isYPServerConfigured
        isMaster = detected == :master

        slave_or_master = isMaster ?
          # To translators: part of the label in the dialog
          _("Master") :
          # To translators: part of the label in the dialog
          _("Slave")
        # To translators: label in the dialog, %1 is Master or Slave above
        labels << Left(Label(Builtins.sformat(
          _("A NIS %1 Server is configured."), slave_or_master
        )))

        # To translators: label in the dialog
        reconfigure_master = _("Reconfigure NIS &Master Server")
        # To translators: label in the dialog
        change_to_master = _("Change to NIS &Master Server")
        # To translators: label in the dialog
        reconfigure_slave = _("Reconfigure NIS &Slave Server")
        # To translators: label in the dialog
        change_to_slave = _("Change to NIS &Slave Server")

        master_setup_label = isMaster ? reconfigure_master : change_to_master
        slave_setup_label = isMaster ? change_to_slave : reconfigure_slave
        # To translators: label in the dialog
        none_setup_label = _("&Deactivate any NIS server configuration")
      else
        # To translators: label in the dialog
        labels << Left(Label(_("NIS Software is installed.")))
        # To translators: label in the dialog
        labels << Left(Label(_("No NIS Server is configured.")))

        # To translators: checkbox label
        master_setup_label = _("Create NIS &Master Server")
        # To translators: checkbox label
        slave_setup_label = _("Create NIS &Slave Server")
        # To translators: checkbox label
        none_setup_label = _("&Do nothing and leave set up")
      end

      info = HBox()
      # To translators: label in the dialog
      info << VBox(Label(_("Current status:")))
      info << HSpacing(4)
      info << labels

      buttons = VBox()
      buttons << VSpacing(0.5)
      buttons << Left(
                  RadioButton(
                    Id(:master),
                    Opt(:notify),
                    master_setup_label,
                    detected == :master
                  )
                )
      buttons << VSpacing(0.2)
      buttons << Left(
                   RadioButton(
                     Id(:slave),
                     Opt(:notify),
                     slave_setup_label,
                     detected == :slave
                   )
                 )
      buttons << VSpacing(0.2)
      buttons << Left(
                   RadioButton(
                     Id(:none),
                     Opt(:notify),
                     none_setup_label,
                     detected == :none
                   )
                 )
      buttons << VSpacing(0.5)

      buttons = HBox(HSpacing(0.5), buttons, HSpacing(0.5))

      buttons = HVSquash(RadioButtonGroup(Id(:rb), buttons))

      contents = VBox()
      contents = Builtins.add(contents, info)
      contents = Builtins.add(contents, VSpacing())
      # To translators: frame label
      contents = Builtins.add(
        contents,
        VCenter(Frame(_("Select what you want to do"), buttons))
      )
      contents = Builtins.add(contents, VStretch())

      # To translators: dialog label
      Wizard.SetContents(
        _("Network Information Service (NIS) Server Setup"),
        contents,
        helptext,
        true,
        true
      )

      ui = nil
      current_button = nil
      begin
        current_button = Convert.to_symbol(
          UI.QueryWidget(Id(:rb), :CurrentButton)
        )

        if current_button == :none
          Wizard.SetNextButton(:finish, Label.FinishButton)
        elsif Builtins.contains([:master, :slave], current_button)
          Wizard.RestoreNextButton
        end

        Wizard.SetFocusToNextButton

        ui = Convert.to_symbol(UI.UserInput)
        ui = :abort if ui == :cancel || ui == :back

        if ui == :abort && NisServer.modified && !Popup.ReallyAbort(true)
          ui = :again
        end
      end until Builtins.contains([:back, :next, :abort, :finish], ui)

      return :abort if ui == :abort
      return :exit if ui == :back
      if ui == :finish && (detected == :none || !isYPServerConfigured)
        return :nothing
      end

      current_button = Convert.to_symbol(
        UI.QueryWidget(Id(:rb), :CurrentButton)
      )

      NisServer.modified = true if NisServer.ui_what != current_button

      NisServer.ui_what = current_button
      ui == :next ? current_button : ui
    end
  end
end
