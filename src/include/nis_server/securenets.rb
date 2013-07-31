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
#   securenets.ycp
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
  module NisServerSecurenetsInclude
    def initialize_nis_server_securenets(include_target)
      Yast.import "UI"

      textdomain "nis_server"

      Yast.import "NisServer"
      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "IP"
    end

    # Creates items for table from var_yp_securenets.scr any agent
    # @param [Array<Hash>] nets list of output from securenets agent
    #		<br>$["netmask": "255.0.0.0", "network": "10.0.0.0"]
    # @return a list of items formated for a UI table
    def ItemizeSecurenets(nets)
      nets = deep_copy(nets)
      not_comment = Builtins.filter(nets) do |e|
        Builtins.haskey(e, "netmask") || Builtins.haskey(e, "network")
      end
      result = []
      i = 0
      Builtins.foreach(not_comment) do |element|
        result = Builtins.add(
          result,
          Item(
            Id(i),
            Ops.get_string(element, "netmask", ""),
            Ops.get_string(element, "network", "")
          )
        )
        i = Ops.add(i, 1)
      end
      deep_copy(result)
    end

    # Merge edited entries with the original entries with comments
    # @param [Array<Hash>] orig list of original entries (with comments)
    # @param [Array<Yast::Term>] edit list with edited entries (as placed in the table)
    # @return [Array] with merged entries
    def MergeNetsEntries(orig, edit)
      orig = deep_copy(orig)
      edit = deep_copy(edit)
      edit_maps = Builtins.maplist(edit) do |e|
        {
          "netmask" => Ops.get_string(e, 1, ""),
          "network" => Ops.get_string(e, 2, "")
        }
      end


      result = Builtins.filter(orig) do |e|
        Builtins.haskey(e, "hash") || Builtins.haskey(e, "comment") ||
          Builtins.contains(edit_maps, e)
      end
      edit_maps = Builtins.filter(edit_maps) do |e|
        !Builtins.contains(result, e)
      end
      result = Ops.add(result, edit_maps)

      deep_copy(result)
    end

    # Popup dialog for editing netmask/network
    # @param [Fixnum] id id of item
    # @param [String] netmask netmask
    # @param [String] network network
    # @return a new item or nil on cancel
    def NetsEditPopup(id, netmask, network)
      contents = HBox(
        HSpacing(),
        VBox(
          VSpacing(0.3),
          # To translators: popup dialog heading
          Heading(_("Edit netmask and network")),
          VSpacing(0.5),
          # To translators: textentry label
          InputField(Id(:netmask), Opt(:hstretch), _("Net&mask"), netmask),
          VSpacing(0.3),
          # To translators: textentry label
          InputField(Id(:network), Opt(:hstretch), _("Net&work"), network),
          VSpacing(0.5),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          ),
          VSpacing(0.3)
        ),
        HSpacing()
      )

      UI.OpenDialog(contents)
      UI.SetFocus(Id(:netmask))

      ui = nil
      error_msg = ""
      begin
        error_msg = ""
        ui = Convert.to_symbol(UI.UserInput)

        if ui == :ok
          netmask = Convert.to_string(UI.QueryWidget(Id(:netmask), :Value))
          network = Convert.to_string(UI.QueryWidget(Id(:network), :Value))
          # explicitly allow 0.0.0.0
          if netmask != "0.0.0.0" && !IP.Check4(netmask)
            # To translators: error message
            error_msg = Ops.add(error_msg, _("Wrong netmask!\n"))
          end
          # To translators: error message
          error_msg = Ops.add(
            error_msg,
            IP.Check4(network) ? "" : _("Wrong network!\n")
          )

          if Ops.greater_than(Builtins.size(error_msg), 0)
            Popup.Error(error_msg)
          end
        end
      end until error_msg == "" && ui == :ok || ui == :cancel

      UI.CloseDialog

      ui == :ok ? Item(Id(id), netmask, network) : nil
    end

    # Securenets dialog
    # @return `back, `next or `abort
    def QueryHosts
      # help text 1/4
      helptext = _(
        "<p>Please enter which hosts are allowed to query the NIS server.</p>"
      )
      # help text 2/4
      helptext = Ops.add(
        helptext,
        _(
          "<p>A host address will be allowed if <b>network</b> is equal\nto the  bitwise <i>AND</i> of the host's address and the <b>netmask</b>.</p>"
        )
      )
      # help text 3/4
      helptext = Ops.add(
        helptext,
        _(
          "<p>The entry with <b>netmask</b> <tt>255.0.0.0</tt> and <b>network</b>\n<tt>127.0.0.0</tt> must exist to allow connections from the local host.</p>\n"
        )
      )
      # help text 4/4
      helptext = Ops.add(
        helptext,
        _(
          "<p>Entering <b>netmask</b> <tt>0.0.0.0</tt> and\n<b>network</b> <tt>0.0.0.0</tt> gives access to all hosts.</p>"
        )
      )

      allow_query = ItemizeSecurenets(NisServer.securenets)
      n_items = Builtins.size(allow_query)

      contents = VBox(
        Table(
          Id(:table),
          Opt(:notify, :immediate),
          Header(
            # To translators: table header
            _("Netmask"),
            # To translators: table header
            _("Network")
          ),
          allow_query
        ),
        HBox(
          PushButton(Id(:add), Label.AddButton),
          PushButton(Id(:edit), Label.EditButton),
          PushButton(Id(:delete), Label.DeleteButton),
          HStretch()
        )
      )

      # To translators: dialog label
      Wizard.SetContents(
        _("NIS Server Query Hosts Setup"),
        contents,
        helptext,
        true,
        true
      )
      Wizard.SetNextButton(:next, Label.FinishButton)

      ui = nil
      begin
        anyitems = UI.QueryWidget(Id(:table), :CurrentItem) != nil
        UI.ChangeWidget(Id(:edit), :Enabled, anyitems)
        UI.ChangeWidget(Id(:delete), :Enabled, anyitems)

        # Kludge, because a `Table still does not have a shortcut. #16116
        UI.SetFocus(Id(:table))

        ui = Convert.to_symbol(UI.UserInput)
        ui = :abort if ui == :cancel

        if ui == :delete
          id = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
          allow_query = Builtins.filter(allow_query) do |e|
            id != Ops.get_integer(e, [0, 0], -1)
          end
          UI.ChangeWidget(Id(:table), :Items, allow_query)
        elsif ui == :edit
          id = Convert.to_integer(UI.QueryWidget(Id(:table), :CurrentItem))
          item = Builtins.find(allow_query) do |e|
            id == Ops.get_integer(e, [0, 0], -1)
          end
          item = NetsEditPopup(
            id,
            Ops.get_string(item, 1, ""),
            Ops.get_string(item, 2, "")
          )
          if item != nil
            allow_query = Builtins.maplist(allow_query) do |e|
              Ops.get_integer(e, [0, 0], -1) == id ? item : e
            end
            UI.ChangeWidget(Id(:table), :Items, allow_query)
          end
        elsif ui == :add
          new_item = NetsEditPopup(n_items, "", "")
          if new_item != nil
            n_items = Ops.add(n_items, 1)
            allow_query = Builtins.add(allow_query, new_item)
            UI.ChangeWidget(Id(:table), :Items, allow_query)
          end
        end

        ui = :again if ui == :abort && !Popup.ReallyAbort(NisServer.modified)
      end until Builtins.contains([:back, :next, :abort], ui)

      Wizard.RestoreNextButton if ui == :back

      securenets = MergeNetsEntries(NisServer.securenets, allow_query)

      # and finally merge
      if ui == :next &&
          Builtins.sort(securenets) != Builtins.sort(NisServer.securenets)
        NisServer.securenets = deep_copy(securenets)
        NisServer.modified = true
      end
      ui
    end
  end
end
