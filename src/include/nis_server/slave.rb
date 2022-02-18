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
#   slave.ycp
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
# YPServer module part.
#
module Yast
  module NisServerSlaveInclude
    def initialize_nis_server_slave(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "Wizard"
      Yast.import "Popup"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "NisServer"
      Yast.import "Nis"
      Yast.import "Address"
      Yast.include include_target, "nis_server/routines.rb"
    end

    # Slave dialog
    # @return `back, `abort or `next
    def SlaveDialog
      firewall_widget = GetFirewallWidget()
      firewall_layout = Ops.get_term(firewall_widget, "custom_widget", VBox())

      # help text 1/2
      helptext = _(
        "<p>Enter the NIS <b>domain</b> and the IP <b>address</b> or host name of the master NIS server.</p>"
      )
      # help text 2/2
      helptext = Ops.add(
        Ops.add(
          helptext,
          _(
            "<p>If this host is also a NIS client using this machine as a server, check the corresponding option.</p>"
          )
        ),
        Ops.get_string(firewall_widget, "help", "")
      )

      contents = HVSquash(
        VBox(
          # textentry label
          InputField(
            Id(:domain),
            Opt(:hstretch),
            _("N&IS Domain Name:"),
            NisServer.domain
          ),
          VSpacing(0.5),
          InputField(
            Id(:master_ip),
            Opt(:hstretch),
            # text entry label
            _("NIS &Master Server:"),
            NisServer.ui_master_ip
          ),
          VSpacing(),
          Left(
            CheckBox(
              Id(:also_client),
              # checkbox label
              _("This host is also a NIS &client"),
              NisServer.start_ypbind
            )
          ),
          VSpacing(2),
          firewall_layout
        )
      )

      # To translators: dialog label, worker used to be known as slave
      Wizard.SetContents(
        _("Worker Server Setup"),
        contents,
        helptext,
        true,
        true
      )

      CWMFirewallInterfaces.OpenFirewallInit(firewall_widget, "")

      event = {}
      ui = nil
      begin
        event = UI.WaitForEvent
        ui = Ops.get(event, "ID")
        CWMFirewallInterfaces.OpenFirewallHandle(firewall_widget, "", event)
        ui = :abort if ui == :cancel

        if ui == :next
          master_ip = Convert.to_string(UI.QueryWidget(Id(:master_ip), :Value))
          domainname = Convert.to_string(UI.QueryWidget(Id(:domain), :Value))
          start_ypbind = Convert.to_boolean(
            UI.QueryWidget(Id(:also_client), :Value)
          )
          if !Address.Check4(master_ip)
            # To translators: error message
            UI.SetFocus(Id(:master_ip))
            Popup.Error(Address.Valid4)
            ui = :again
            next
          elsif !Nis.check_nisdomainname(domainname)
            UI.SetFocus(Id(:domain))
            Popup.Error(Nis.valid_nisdomainname)
            ui = :again
            next
          end
          if master_ip != NisServer.ui_master_ip ||
              domainname != NisServer.domain ||
              start_ypbind != NisServer.start_ypbind
            NisServer.modified = true
          end

          CheckForDHCPClient(domainname)
          CWMFirewallInterfaces.OpenFirewallStore(firewall_widget, "", event)
          NisServer.start_ypbind = start_ypbind
          NisServer.ui_master_ip = master_ip
          NisServer.domain = domainname
        end

        ui = :again if ui == :abort && !Popup.ReallyAbort(NisServer.modified)
      end until ui == :next || ui == :back || ui == :abort

      Convert.to_symbol(ui)
    end
  end
end
