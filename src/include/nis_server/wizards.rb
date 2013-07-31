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

# File:	include/nis_server/wizards.ycp
# Package:	Configuration of NIS server
# Summary:	Wizards definitions
# Authors:	Martin Vidner <mvidner@suse.cz>
#              Dan Vesely <dan@suse.cz>
#
# $Id$
module Yast
  module NisServerWizardsInclude
    def initialize_nis_server_wizards(include_target)
      Yast.import "UI"
      textdomain "nis_server"

      Yast.import "Wizard"
      Yast.import "Label"
      Yast.import "Sequencer"

      Yast.include include_target, "nis_server/ui.rb"
    end

    # Main workflow of the NIS server configuration
    # @return sequence result
    def MainSequence
      aliases = {
        "begin"        => lambda { WhatToConfigure() },
        "exit_popup"   => lambda { ExitPopup() },
        "install"      => [lambda { InstallServer() }, true],
        "slave"        => lambda { SlaveDialog() },
        "query_hosts"  => lambda { QueryHosts() },
        "master"       => lambda { MasterDialog() },
        "details"      => lambda { DetailsDialog() },
        "maps"         => lambda { MapsDialog() },
        "decide"       => [lambda { SlaveExists() }, true],
        "master_slave" => lambda { MastersSlavesDialog() }
      }

      sequence = {
        "ws_start"     => "begin",
        "begin"        => {
          :slave   => "install",
          :master  => "install",
          :finish  => :next,
          :abort   => :abort,
          :exit    => "exit_popup",
          :nothing => :nothing
        },
        "exit_popup"   => { :exit => :exit, :back => "begin" },
        "install"      => {
          :master => "master",
          :slave  => "slave",
          :abort  => :abort
        },
        "slave"        => { :next => "query_hosts", :abort => :abort },
        "master"       => {
          :next    => "decide",
          :details => "details",
          :abort   => :abort
        },
        "details"      => { :next => "master", :abort => :abort },
        "decide"       => {
          :have_slave => "master_slave",
          :none_slave => "maps",
          :abort      => :abort
        },
        "master_slave" => { :next => "maps", :abort => :abort },
        "maps"         => { :next => "query_hosts", :abort => :abort },
        "query_hosts"  => { :next => :next, :abort => :abort }
      }

      ret = Sequencer.Run(aliases, sequence)

      ret
    end


    # Whole configuration of NIS server
    # @return sequence result
    def NisServerSequence
      aliases = {
        "read"          => [lambda { ReadDialog() }, true],
        "main"          => lambda { MainSequence() },
        "write"         => [lambda { WriteDialog() }, true],
        "result"        => lambda { ResultPopup() },
        "error_details" => lambda { DetailsPopup() }
      }

      sequence = {
        "ws_start"      => "read",
        "read"          => { :abort => :abort, :next => "main" },
        "main"          => {
          :abort   => :abort,
          :nothing => :nothing,
          :next    => "write"
        },
        "write"         => { :next => "result" },
        "result"        => { :ok => :next, :details => "error_details" },
        "error_details" => { :ok => "result" }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopTitleAndIcon("nis_server")
      ret = Sequencer.Run(aliases, sequence)

      UI.CloseDialog
      ret
    end

    # Whole configuration of NIS server but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def NisServerAutoSequence
      # Translators: dialog caption
      caption = _("NIS Server Configuration")
      # label
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = MainSequence()

      UI.CloseDialog
      ret
    end
  end
end
