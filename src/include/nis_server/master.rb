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
#   master.ycp
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
  module NisServerMasterInclude
    def initialize_nis_server_master(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "Nis" # check_nisdomainname
      Yast.import "NisServer"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "nis_server/routines.rb"
    end

    # Master dialog
    # @return `back, `abort, `next or `details
    def MasterDialog
      pwd_chfn = NisServer.pwd_chfn
      pwd_chsh = NisServer.pwd_chsh
      start_yppasswdd = NisServer.start_yppasswdd
      domain = NisServer.domain
      start_ypbind = NisServer.start_ypbind
      nopush = NisServer.nopush
      start_ypxfrd = NisServer.start_ypxfrd

      firewall_widget = GetFirewallWidget()
      firewall_layout = Ops.get_term(firewall_widget, "custom_widget", VBox())

      # help text 1/3
      helptext = _(
        "<p>Enter a NIS <b>domain</b>. If this host is also a NIS client using this machine as a server, check\nthe corresponding option.</p>\n"
      )

      # help text 2/3
      # TRANSLATORS: workers or worker servers used to be known as slave servers before
      helptext = Ops.add(
        helptext,
        _(
          "<p>For worker servers to cooperate with this master, check\n" +
            "<i>Active Worker NIS server exists</i>. If you check\n" +
            "<i>Fast Map distribution</i>, it will speed up the transfer of maps to the\n" +
            "workers.</p>\n"
        )
      )

      # help text 3/3
      helptext = Ops.add(
        helptext,
        _(
          "<p><i>Allow changes to passwords</i> lets the users change their\n" +
            "passwords in the presence of NIS. Buttons to allow\n" +
            "changing the login shell or GECOS (full name and related information) can\n" +
            "be used to set up these more specific options.</p>\n"
        )
      )

      helptext = Ops.add(helptext, Ops.get_string(firewall_widget, "help", ""))

      pass_yes_buttons = HBox(
        HSpacing(3),
        VBox(
          Left(
            CheckBox(
              Id(:allow_gecos),
              # To translators: checkbox label
              _("Allow changes to &GECOS field"),
              pwd_chfn
            )
          ),
          Left(
            CheckBox(
              Id(:allow_shell),
              # To translators: checkbox label
              _("Allow changes to login &shell"),
              pwd_chsh
            )
          )
        )
      )

      pass_buttons = HBox(
        HSpacing(),
        VBox(
          VSpacing(0.3),
          Left(
            CheckBox(
              Id(:change_passwords),
              Opt(:notify),
              # To translators: checkbox label
              _("Allow changes to &passwords"),
              start_yppasswdd
            )
          ),
          VSpacing(0.3),
          pass_yes_buttons,
          VSpacing(0.3)
        )
      )

      domain_frame = HBox(
        HSpacing(),
        VBox(
          VSpacing(0.3),
          InputField(Id(:domain), Opt(:hstretch), "", domain),
          VSpacing(0.3),
          Left(
            CheckBox(
              Id(:also_client),
              # To translators: checkbox label
              _("This host is also a NIS &client"),
              start_ypbind
            )
          ),
          VSpacing(0.3)
        ),
        HSpacing(4)
      )

      contents = HBox(
        HSpacing(4),
        VBox(
          VSpacing(0.5),
          # To translators: frame label
          Frame(_("NIS &Domain Name"), domain_frame),
          VSpacing(0.5),
          Left(
            CheckBox(
              Id(:have_slave),
              # To translators: checkbox label
              _("Active Worker NIS server &exists"),
              !nopush
            )
          ),
          VSpacing(0.5),
          Left(
            CheckBox(
              Id(:fast_map),
              # To translators: checkbox label
              _("&Fast Map distribution (rpc.ypxfrd)"),
              start_ypxfrd
            )
          ),
          VSpacing(0.5),
          # To translators: frame label
          Frame(_("Changing of passwords"), pass_buttons),
          VSpacing(0.5),
          firewall_layout,
          VSpacing(0.5),
          PushButton(
            Id(:details),
            Opt(:key_F7),
            # To translators: pushbutton label
            _("&Other global settings ...")
          )
        ),
        HSpacing(6)
      )

      # To translators: dialog label
      Wizard.SetContents(
        _("Master Server Setup"),
        contents,
        helptext,
        true,
        true
      )

      UI.ChangeWidget(Id(:allow_shell), :Enabled, start_yppasswdd)
      UI.ChangeWidget(Id(:allow_gecos), :Enabled, start_yppasswdd)

      CWMFirewallInterfaces.OpenFirewallInit(firewall_widget, "")

      event = {}
      ui = nil
      begin
        event = UI.WaitForEvent
        ui = Ops.get(event, "ID")
        CWMFirewallInterfaces.OpenFirewallHandle(firewall_widget, "", event)
        ui = :abort if ui == :cancel

        if ui == :change_passwords
          start_yppasswdd = Convert.to_boolean(
            UI.QueryWidget(Id(:change_passwords), :Value)
          )
          UI.ChangeWidget(Id(:allow_shell), :Enabled, start_yppasswdd)
          UI.ChangeWidget(Id(:allow_gecos), :Enabled, start_yppasswdd)
        end

        if ui == :details || ui == :next
          domainname = Convert.to_string(UI.QueryWidget(Id(:domain), :Value))

          if !Nis.check_nisdomainname(domainname)
            UI.SetFocus(Id(:domain))
            Popup.Error(Nis.valid_nisdomainname)
            ui = :again
            next
          end
          domain = domainname
          start_ypbind = Convert.to_boolean(
            UI.QueryWidget(Id(:also_client), :Value)
          )
          nopush = !Convert.to_boolean(UI.QueryWidget(Id(:have_slave), :Value))
          pwd_chfn = Convert.to_boolean(
            UI.QueryWidget(Id(:allow_gecos), :Value)
          )
          pwd_chsh = Convert.to_boolean(
            UI.QueryWidget(Id(:allow_shell), :Value)
          )
          start_yppasswdd = Convert.to_boolean(
            UI.QueryWidget(Id(:change_passwords), :Value)
          )
          start_ypxfrd = Convert.to_boolean(
            UI.QueryWidget(Id(:fast_map), :Value)
          )

          CheckForDHCPClient(domainname)
          CWMFirewallInterfaces.OpenFirewallStore(firewall_widget, "", event)

          if NisServer.modified || domain != NisServer.domain ||
              start_ypbind != NisServer.start_ypbind ||
              nopush != NisServer.nopush ||
              pwd_chfn != NisServer.pwd_chfn ||
              pwd_chsh != NisServer.pwd_chsh ||
              start_yppasswdd != NisServer.start_yppasswdd ||
              start_ypxfrd != NisServer.start_ypxfrd
            NisServer.modified = true
            NisServer.domain = domain
            NisServer.start_ypbind = start_ypbind
            NisServer.nopush = nopush
            NisServer.pwd_chfn = pwd_chfn
            NisServer.pwd_chsh = pwd_chsh
            NisServer.start_yppasswdd = start_yppasswdd
            NisServer.start_ypxfrd = start_ypxfrd
          end
        end

        ui = :again if ui == :abort && !Popup.ReallyAbort(NisServer.modified)
      end until Ops.is_symbol?(ui) &&
        Builtins.contains(
          [:next, :back, :abort, :details],
          Convert.to_symbol(ui)
        )

      Convert.to_symbol(ui)
    end
  end
end
