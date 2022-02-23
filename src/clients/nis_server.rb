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

# File:	clients/nis_server.ycp
# Package:	Configuration of NIS server
# Summary:	Main file
# Authors:	Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Main file for NIS server configuration. Uses all other files.
module Yast
  class NisServerClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of the NIS server</h3>

      textdomain "nis_server"

      Yast.import "CommandLine"
      Yast.import "IP"
      Yast.import "Nis"
      Yast.import "NisServer"
      Yast.import "Package"
      Yast.import "Report"
      Yast.import "Summary"

      Yast.include self, "nis_server/wizards.rb"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("NisServer module started")

      # the command line description map
      @cmdline = {
        "id"         => "nis-server",
        # translators: command line help text for nis server module
        "help"       => _(
          "NIS server configuration module."
        ),
        "guihandler" => fun_ref(method(:NisServerSequence), "symbol ()"),
        "initialize" => fun_ref(NisServer.method(:Read), "boolean ()"),
        "finish"     => fun_ref(NisServer.method(:Write), "boolean ()"),
        "actions" =>
          # configure
          {
            "summary" => {
              "handler" => fun_ref(
                method(:NisServerSummaryHandler),
                "boolean (map)"
              ),
              # command line help text for 'summary' action
              "help"    => _(
                "Configuration summary of NIS server"
              )
            },
            "stop"    => {
              "handler" => fun_ref(
                method(:NisServerStopHandler),
                "boolean (map)"
              ),
              # command line action help
              "help"    => _("Stop NIS server")
            },
            "master"  => {
              "handler" => fun_ref(
                method(:NisServerMasterHandler),
                "boolean (map)"
              ),
              # command line action help
              "help"    => _(
                "Configure NIS master server"
              )
            },
            "slave"   => {
              "handler" => fun_ref(
                method(:NisServerSlaveHandler),
                "boolean (map)"
              ),
              # command line action help
              # TRANSLATORS: help for the "slave" action. It is obsoleted by the "worker" action
              "help"    => _(
                "Configure NIS worker server (obsolete)"
              )
            },
            "worker"   => {
              "handler" => fun_ref(
                method(:NisServerSlaveHandler),
                "boolean (map)"
              ),
              # command line action help
              "help"    => _(
                "Configure NIS worker server"
              )
            }
          },
        "options"    => {
          "domain"     => {
            # command line help text for the 'domain' option
            "help" => _(
              "NIS domain"
            ),
            "type" => "string"
          },
          "master_ip"  => {
            # command line help text for the 'master_ip' option
            "help" => _(
              "IP address of master NIS server"
            ),
            "type" => "string"
          },
          "yppasswd"   => {
            # command line help text for the 'yppasswd' option
            "help"     => _(
              "Start or stop yppasswd service"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "ypdir"      => {
            # command line help text for the 'ypdir' option
            "help" => _(
              "YP source directory"
            ),
            "type" => "string"
          },
          "maps"       => {
            # command line help text for the 'maps' option
            "help" => _(
              "Maps distributed by server"
            ),
            "type" => "string"
          },
          "securenets" => {
            # command line help text for the 'hosts' option
            "help" => _(
              "Hosts allowed to query server ('netmask:network')"
            ),
            "type" => "string"
          }
        },
        "mappings"   => {
          "summary" => [],
          "master"  => ["domain", "yppasswd", "ypdir", "maps", "securenets"],
          "slave"   => ["domain", "master_ip", "securenets"]
        }
      }

      @ret = CommandLine.Run(@cmdline)

      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("NisServer module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # Print summary of basic options
    # @return [Boolean] false
    def NisServerSummaryHandler(options)
      options = deep_copy(options)
      if NisServer.ui_what == :none
        # summary label
        CommandLine.Print(_("No NIS Server is configured."))
        return false
      end

      if NisServer.ui_what == :master
        # summary label
        CommandLine.Print(_("A NIS master server is configured."))
      else
        # summary label
        CommandLine.Print(_("A NIS worker server is configured."))
      end

      # summary label
      CommandLine.Print(
        Builtins.sformat(
          "%1: %2",
          _("NIS Domain"),
          NisServer.domain != "" ? NisServer.domain : Summary.NotConfigured
        )
      )

      if NisServer.ui_what == :master
        # summary label:
        CommandLine.Print(
          Ops.add(_("YP Source Directory: "), NisServer.pwd_srcdir)
        )
        # summary label:
        CommandLine.Print(
          Ops.add(
            _("Available Maps: "),
            Builtins.mergestring(NisServer.maps, ",")
          )
        )
      else
        # summary label:
        CommandLine.Print(
          Ops.add(
            _("NIS Master Server: "),
            NisServer.ui_master_ip != "" ?
              NisServer.ui_master_ip :
              Summary.NotConfigured
          )
        )
      end
      allow_query = ItemizeSecurenets(NisServer.securenets)
      if Ops.greater_than(Builtins.size(allow_query), 0)
        net = Builtins.mergestring(Builtins.maplist(allow_query) do |t|
          Builtins.mergestring(
            [Ops.get_string(t, 1, ""), Ops.get_string(t, 2, "")],
            ":"
          )
        end, "\n")
        # summary label (netmask:network shows output format)
        CommandLine.Print(
          Builtins.sformat(
            _("Hosts Allowed to Query Server (netmask:network):\n%1"),
            net
          )
        )
      end
      false # do not call Write...
    end

    # stop server
    def NisServerStopHandler(options)
      options = deep_copy(options)
      return false if NisServer.ui_what == :none
      NisServer.ui_what = :none
      true
    end

    # check if neccessary packages are installed
    def check_packages
      packages = deep_copy(NisServer.required_packages)
      if !Package.InstalledAny(packages)
        # error message
        Report.Error(
          Builtins.sformat(
            _("Required packages (%1) are not installed."),
            Builtins.mergestring(NisServer.required_packages, ",")
          )
        )
        return false
      end
      true
    end


    # check validity of "securenets" command line option
    # on error, report error message and return nil
    def update_securenets(securenets)
      nets = Builtins.splitstring(securenets, ",;")
      error = ""
      i = -1
      items = Builtins.maplist(nets) do |net|
        netlist = Builtins.splitstring(net, ":")
        netmask = Ops.get_string(netlist, 0, "")
        network = Ops.get_string(netlist, 1, "")
        if netmask != "0.0.0.0" && !IP.Check4(netmask)
          # error message
          error = Ops.add(
            error,
            Builtins.sformat(_("Invalid netmask: %1.\n"), netmask)
          )
        end
        if !IP.Check4(network)
          # error message
          error = Ops.add(
            error,
            Builtins.sformat(_("Invalid network: %1.\n"), network)
          )
        end
        i = Ops.add(i, 1)
        Item(Id(i), netmask, network)
      end
      if error != ""
        Report.Error(Ops.add(error, IP.Valid4))
        return nil
      end
      MergeNetsEntries(NisServer.securenets, items)
    end

    # configure master server
    def NisServerMasterHandler(options)
      options = deep_copy(options)
      return false if !check_packages

      domain = NisServer.domain
      if Ops.get_string(options, "domain", "") != ""
        domain = Ops.get_string(options, "domain", "")
      end
      if !Nis.check_nisdomainname(domain)
        Report.Error(Nis.valid_nisdomainname)
        return false
      end
      pwd_srcdir = NisServer.pwd_srcdir
      if Ops.get_string(options, "ypdir", "") != ""
        pwd_srcdir = Ops.get_string(options, "ypdir", pwd_srcdir)
      end

      securenets = deep_copy(NisServer.securenets)
      if Ops.get_string(options, "securenets", "") != ""
        securenets = update_securenets(
          Ops.get_string(options, "securenets", "")
        )
        return false if securenets == nil
      end

      maps = deep_copy(NisServer.maps)
      if Ops.get_string(options, "maps", "") != ""
        maps = Builtins.splitstring(Ops.get_string(options, "maps", ""), ",;:")
        all = NisServer.GetAllMaps
        files = Builtins.listmap(all) do |table|
          { table => Ops.add("/etc/", table) }
        end
        Builtins.foreach(["passwd", "group", "passwd.adjunct", "shadow"]) do |table|
          Ops.set(files, table, Builtins.sformat("%1/%2", pwd_srcdir, table))
        end
        Ops.set(files, "netgrp", "/etc/netgroup")
        Ops.set(files, "mail", "/etc/mail/aliases")

        all = Builtins.filter(all) do |table|
          next false if NisServer.merge_passwd && table == "shadow"
          if Builtins.contains(NisServer.maps, table) # current are ok?
            next true
          end
          Ops.greater_or_equal(
            SCR.Read(path(".target.size"), Ops.get_string(files, table, "/")),
            0
          )
        end
        unsup = Builtins.filter(maps) { |table| !Builtins.contains(all, table) }
        if Ops.greater_than(Builtins.size(unsup), 0)
          # error message
          Report.Error(
            Builtins.sformat(
              _("These maps are not supported:\n%1"),
              Builtins.mergestring(unsup, ",")
            )
          )
          return false
        end
      end


      if Ops.get_string(options, "yppasswd", "") != ""
        NisServer.start_yppasswdd = Ops.get_string(options, "yppasswd", "") == "yes"
      end

      NisServer.maps = deep_copy(maps)
      NisServer.securenets = deep_copy(securenets)
      NisServer.pwd_srcdir = pwd_srcdir
      NisServer.domain = domain
      NisServer.ui_what = :master
      true
    end

    # configure NIS slave server
    def NisServerSlaveHandler(options)
      options = deep_copy(options)
      return false if !check_packages

      domain = NisServer.domain
      if Ops.get_string(options, "domain", "") != ""
        domain = Ops.get_string(options, "domain", "")
      end
      if !Nis.check_nisdomainname(domain)
        Report.Error(Nis.valid_nisdomainname)
        return false
      end

      securenets = deep_copy(NisServer.securenets)
      if Ops.get_string(options, "securenets", "") != ""
        securenets = update_securenets(
          Ops.get_string(options, "securenets", "")
        )
        return false if securenets == nil
      end

      master_ip = NisServer.ui_master_ip
      if Ops.get_string(options, "master_ip", "") != ""
        master_ip = Ops.get_string(options, "master_ip", "")
      end
      if master_ip == ""
        # error message
        Report.Error(_("NIS master server IP was not specified."))
        return false
      end
      if !IP.Check4(master_ip)
        Report.Error(IP.Valid4)
        return false
      end

      NisServer.securenets = deep_copy(securenets)
      NisServer.domain = domain
      NisServer.ui_master_ip = master_ip
      NisServer.ui_what = :slave
      true
    end
  end
end

Yast::NisServerClient.new.main
