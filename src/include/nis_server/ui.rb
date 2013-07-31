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

# File:	include/nis_server/dialogs.ycp
# Package:	Configuration of nisServer
# Summary:	Dialogs definitions
# Authors:	Martin Vidner <mvidner@suse.cz>
#              Dan Vesely <dan@suse.cz>
#
# $Id$
module Yast
  module NisServerUiInclude
    def initialize_nis_server_ui(include_target)
      Yast.import "UI"
      textdomain "nis_server"

      Yast.import "Confirm"
      Yast.import "Label"
      Yast.import "Message"
      Yast.import "NisServer"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "nis_server/what.rb"
      Yast.include include_target, "nis_server/slave.rb"
      Yast.include include_target, "nis_server/master.rb"
      Yast.include include_target, "nis_server/details.rb"
      Yast.include include_target, "nis_server/slaves.rb"
      Yast.include include_target, "nis_server/maps.rb"
      Yast.include include_target, "nis_server/securenets.rb"
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      # checking for root permissions (#158483)
      return :abort if !Confirm.MustBeRoot

      ret = NisServer.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreNextButton
      Wizard.DisableNextButton
      UI.ChangeWidget(Id(:abort), :Enabled, false)

      ret = NisServer.Write
      ret ? :next : :abort
    end

    # Popup to confirm after finish is pressed
    # @return `yes or `back
    def FinishPopup
      if Popup.ContinueCancelHeadline(
          # To translators: ContinueCancel Popup headline
          _("Finish"),
          # To translators: ContinueCancel Popup
          _("Really save configuration ?")
        )
        return :yes
      end
      :back
    end

    # Popup to confirm vhen exitting without saving
    # @return `exit or `back
    def ExitPopup
      if Popup.YesNoHeadline(
          # To translators: YesNo Popup headline
          _("Exit"),
          # To translators: YesNo Popup
          _("Really exit configuration without saving ?")
        )
        return :exit
      end
      :back
    end

    # Popup with details error
    # @return `ok
    def DetailsPopup
      # To translators: popup label
      Popup.LongText(
        _("Error details"),
        RichText(NisServer.error_details),
        50,
        20
      )
      :ok
    end

    # Popup displaying configuration result
    # @return `ok or `details
    def ResultPopup
      message = ""
      if Ops.greater_than(Builtins.size(NisServer.error_msg), 0)
        # To translators: popup label
        message = Builtins.sformat(
          _("Error during configuration:\n%1"),
          NisServer.error_msg
        )

        # To translators: Error popup
        return Popup.AnyQuestion(
          Label.ErrorMsg,
          message,
          Label.OKButton,
          _("&Details"),
          :focus_yes
        ) ? :ok : :details
      else
        if NisServer.start_ypbind && NisServer.old_domainname != "" &&
            NisServer.old_domainname != NisServer.domain
          # To translators: final popup
          Popup.Warning(Message.DomainHasChangedMustReboot)
        end
      end

      :ok
    end

    # Checks if the YP server package is installed
    # and calls installation if not
    # @return `master or `slave
    def InstallServer
      if !Package.InstalledAll(NisServer.required_packages)
        Package.DoInstallAndRemove(NisServer.required_packages, [])
      end

      NisServer.ui_what
    end
  end
end
