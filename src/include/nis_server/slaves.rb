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
#   slaves.ycp
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
  module NisServerSlavesInclude
    def initialize_nis_server_slaves(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "Hostname"
      Yast.import "Label"
      Yast.import "NisServer"
      Yast.import "Popup"
      Yast.import "Wizard"

      Yast.include include_target, "nis_server/routines.rb"

      @hosts = nil
    end

    # Give me one name from the list of hosts
    # @param [Array<String>] hosts list of hosts
    # @return hostname or nil
    def ChooseHostName(hosts)
      hosts = deep_copy(hosts)
      hname = nil

      UI.OpenDialog(
        VBox(
          HSpacing(40),
          HBox(
            VSpacing(10),
            # To translators: selection box label
            SelectionBox(Id(:hosts), _("&Remote hosts"), hosts)
          ),
          HBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )
      ret = nil
      begin
        ret = UI.UserInput
      end while ret != :cancel && ret != :ok

      if ret == :ok
        hname = Convert.to_string(UI.QueryWidget(Id(:hosts), :CurrentItem))
      end

      UI.CloseDialog

      hname
    end


    # Popup for editing a slaver server hostname
    # @param [String] slave	hostname
    # @return	hostname or nil if canceled
    def YPSlavePopup(slave)
      hbox = HBox(
        # To translators: textentry label
        InputField(Id(:slave), Opt(:hstretch), _("&Worker's host name"), slave),
        VBox(
          VSpacing(),
          PushButton(Id(:browse), Opt(:key_F6), Label.BrowseButton)
        )
      )

      contents = HBox(
        HSpacing(),
        VBox(
          VSpacing(0.3),
          # To translators: popup dialog heading
          Heading(_("Edit worker")),
          VSpacing(0.5),
          hbox,
          VSpacing(0.3),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          ),
          VSpacing(0.3)
        ),
        HSpacing()
      )

      UI.OpenDialog(contents)
      UI.SetFocus(Id(:slave))

      ui = nil
      begin
        ui = Convert.to_symbol(UI.UserInput)

        if ui == :ok
          slave = Builtins.tolower(
            Convert.to_string(UI.QueryWidget(Id(:slave), :Value))
          )

          if !Hostname.CheckFQ(slave)
            UI.SetFocus(Id(:slave))
            Popup.Error(Hostname.ValidFQ)
            ui = :again
          end
        elsif ui == :browse
          if @hosts == nil
            # To translators: label message
            UI.OpenDialog(Label(_("Scanning for hosts on this LAN...")))
            @hosts = Builtins.sort(
              Builtins.filter(
                Convert.convert(
                  SCR.Read(path(".net.hostnames")),
                  :from => "any",
                  :to   => "list <string>"
                )
              ) { |host2| Hostname.CheckFQ(host2) }
            )
            UI.CloseDialog
            @hosts = [] if @hosts == nil
          end
          host = ChooseHostName(@hosts)
          if host != nil
            slave = host
            UI.ChangeWidget(Id(:slave), :Value, host)
          end
        end
      end until ui == :ok || ui == :cancel

      UI.CloseDialog

      ui == :ok ? slave : nil
    end

    # Slaves dialog
    # @return `back, `abort or `next
    def MastersSlavesDialog
      # help text 1/1
      helptext = _(
        "<p>Here, enter the names of hosts to configure as NIS server workers. Use <i>Add</i> to add a new one, <i>Edit</i>  to change an existing entry, and <i>Delete</i> to remove an entry.</p>"
      )

      slaves = deep_copy(NisServer.ypservers)

      buttons = HBox(
        PushButton(Id(:add), Label.AddButton),
        PushButton(Id(:edit), Label.EditButton),
        PushButton(Id(:delete), Label.DeleteButton),
        HStretch()
      )

      contents = VBox(
        ReplacePoint(
          Id(:replace),
          # To translators: selection box label
          SelectionBox(
            Id(:slaves),
            Opt(:notify),
            _("&Workers"),
            Builtins.sort(slaves)
          )
        ),
        buttons
      )

      # To translators: dialog label
      Wizard.SetContents(
        _("NIS Master Server Workers Setup"),
        contents,
        helptext,
        true,
        true
      )

      ui = nil
      begin
        anyslaves = UI.QueryWidget(Id(:slaves), :CurrentItem) != nil
        UI.ChangeWidget(Id(:edit), :Enabled, anyslaves)
        UI.ChangeWidget(Id(:delete), :Enabled, anyslaves)

        ui = Convert.to_symbol(UI.UserInput)
        ui = :abort if ui == :cancel

        if ui == :edit
          selected = Convert.to_string(
            UI.QueryWidget(Id(:slaves), :CurrentItem)
          )
          next if selected == nil
          edited = YPSlavePopup(selected)
          if edited != nil
            slaves = Builtins.filter(slaves) { |e| e != selected }
            slaves = Builtins.add(slaves, edited)
            UI.ReplaceWidget(
              Id(:replace),
              SelectionBox(
                Id(:slaves),
                Opt(:notify),
                _("&Workers"),
                Builtins.sort(slaves)
              )
            )
          end
        elsif ui == :delete
          selected = Convert.to_string(
            UI.QueryWidget(Id(:slaves), :CurrentItem)
          )
          next if selected == nil
          slaves = Builtins.filter(slaves) { |e| e != selected }
          UI.ReplaceWidget(
            Id(:replace),
            SelectionBox(
              Id(:slaves),
              Opt(:notify),
              _("&Workers"),
              Builtins.sort(slaves)
            )
          )
        elsif ui == :add
          edited = YPSlavePopup("")
          if edited != nil && !Builtins.contains(slaves, edited)
            slaves = Builtins.add(slaves, edited)
            UI.ReplaceWidget(
              Id(:replace),
              SelectionBox(
                Id(:slaves),
                Opt(:notify),
                _("&Workers"),
                Builtins.sort(slaves)
              )
            )
          end
        end

        ui = :again if ui == :abort && !Popup.ReallyAbort(NisServer.modified)
      end until Builtins.contains([:back, :next, :abort], ui)

      if ui == :next && Builtins.sort(NisServer.ypservers) != slaves
        NisServer.ypservers = deep_copy(slaves)
        NisServer.modified = true
      end

      ui
    end
  end
end
