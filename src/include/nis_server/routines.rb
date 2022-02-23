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
#   routines.ycp
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
  module NisServerRoutinesInclude
    def initialize_nis_server_routines(include_target)
      textdomain "nis_server"

      Yast.import "CWMFirewallInterfaces"
      Yast.import "NisServer"
      Yast.import "Popup"
      Yast.import "Service"
    end

    # @return Checks if the YP server was already configured
    # by reading the SCR, not the module data
    # (not to confuse the user if he backs up to the first dialog)
    def isYPServerConfigured
      Service.Enabled("ypserv")
    end

    # Decides whether slave exists
    # (according to makefile.NOPUSH)
    # @return `have_slave or `none_slave
    def SlaveExists
      NisServer.nopush ? :none_slave : :have_slave
    end

    # Do the check if DHCP client is able to change domain name and
    # warn user about this (see bug #28727)
    def CheckForDHCPClient(domain)
      if NisServer.dhcp_changes_domain
        if NisServer.start_ypbind
          Popup.Warning(
            # warning popup
            _(
              "Your machine is set up to change the NIS domain name via DHCP.\n" +
                "This may replace the domain name just entered. Check your\n" +
                "settings and consider not running a DHCP client on a NIS server.\n"
            )
          )
        end
      end 
      # TODO: check
      # if domain from dhcp client is different then the one currently set

      nil
    end


    # Create the widget for opening firewall ports
    def GetFirewallWidget
      settings = {
        "services"        => ["ypserv"],
        "display_details" => true,
        # firewall openning help
        "help"            => _(
          "<p><b>Firewall Settings</b><br>\n" +
            "To open the firewall to allow accessing the NIS server\n" +
            "from remote computers, set <b>Open Port in Firewall</b>.\n" +
            "To select interfaces on which to open the port, click <b>Firewall Details</b>.\n" +
            "This option is only available if the firewall is enabled.</p>\n"
        )
      }
      CWMFirewallInterfaces.CreateOpenFirewallWidget(settings)
    end
  end
end
