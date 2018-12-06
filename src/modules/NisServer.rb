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

# File:	modules/NisServer.ycp
# Package:	Configuration of NIS server
# Summary:	NIS Server, input and output functions.
# Authors:	Martin Vidner <mvidner@suse.cz>
#              Dan Vesely <dan@suse.cz>
#
# $Id$
#
# Representation of the configuration of nisServer.
# Input and output routines.
require "yast"
require "y2firewall/firewalld"
require "shellwords"

module Yast
  class NisServerClass < Module
    def main
      textdomain "nis_server"

      Yast.import "FileUtils"
      Yast.import "NetworkInterfaces"
      Yast.import "Package"
      Yast.import "Progress"
      Yast.import "Service"
      Yast.import "Summary"

      # Data was modified?
      @modified = false


      #TODO: make this work
      # Write only, used during autoinstallation.
      # Don't run services and SuSEconfig, it's all done at one place.
      @write_only = false

      # ------------------------------------------------------------

      # The domain we are serving.
      # (for simplicity, we assume a single domain)
      # US ".etc.defaultdomain"
      @domain = ""

      # For warning if the domain was changed.
      # TODO delegate to the client module?
      @old_domainname = ""

      # What kind of server to run: `master, `slave, `none
      @ui_what = :none

      # If we are a slave, where is the master?
      #(it may actually be a hostname, TODO solve like in the client using nsswitch)
      @ui_master_ip = ""

      # Maps to be served
      @maps = []

      # Minimal UID to include in the user maps
      @minuid = 0

      # Minimal GID to include in the user maps
      @mingid = 0

      # Merge passwd and shadow to one map?
      # Makefile: string true|false
      @merge_passwd = false

      # Don't push the changes to slave servers. (useful if there aren't any)
      # Makefile: string true|false
      @nopush = false

      # Slave servers
      @ypservers = []

      #
      # **Structure:**
      #
      #     securenet
      #       network: string
      #       netmask: string
      #* or
      #       hash: "#"
      #       (optional) comment: string
      @securenets = []

      # Start also the client? (only when client is configured locally)
      @start_ypbind = false

      # NIS client is configured localy (with current machine as server)
      @nisclient_local = true

      # Start also the map transfer daemon?
      @start_ypxfrd = false

      # Start also the password daemon?
      @start_yppasswdd = false

      # YPPWD_SRCDIR - source directory for passwd data
      @pwd_srcdir = "/etc"

      # YPPWD_CHFN - allow changing the full name?
      @pwd_chfn = false

      # YPPWD_CHSH - allow changing the login shell?
      @pwd_chsh = false

      # If DHCP client could change domain name (#28727)
      @dhcp_changes_domain = false

      # Packages to be installed for this module to operate
      @required_packages = ["ypbind", "ypserv"]


      # ----------------------------------------

      # plain text
      @error_msg = ""
      # rich text
      @error_details = ""
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end


    # ------------------------------------------------------------

    # All tables that ypserv Makefile knows about
    def GetAllMaps
      [
        "passwd",
        "group",
        "hosts",
        "rpc",
        "services",
        "netid",
        "protocols",
        "netgrp",
        "mail",
        "shadow",
        "publickey",
        "networks",
        "ethers",
        "bootparams",
        "printcap",
        "amd.home",
        "auto.master",
        "auto.home",
        "auto.local",
        "passwd.adjunct",
        "timezone",
        "locale",
        "netmasks"
      ]
    end


    # Read all NIS server settings.
    # @return true on success
    def Read
      # help text 1/1
      help = _("<p>Please wait while reading the configuration.</p>")
      # dialog heading
      title = _("Initializing NIS server setup")
      progress_title = " "

      files = [
        "/var/yp/Makefile",
        "/etc/sysconfig/ypserv",
        "/etc/defaultdomain",
        "/var/yp/securenets",
        "/var/yp/ypservers"
      ]

      vars = [
        fun_ref(method(:YPMakefileVars), "void ()"),
        fun_ref(method(:YPServerVars), "void ()"),
        fun_ref(method(:YPSystemVars), "void ()"),
        fun_ref(method(:YPSecurenets), "void ()"),
        fun_ref(method(:YPServers), "void ()")
      ]

      Progress.New(
        title,
        progress_title,
        Ops.add(Builtins.size(files), 3),
        Ops.add(
          # To translators: progress label %1 is filename
          Builtins.maplist(files) do |file|
            Builtins.sformat(_("Load '%1' file"), file)
          end,
          [
            # Trans: progress label
            _("Determine running services"),
            # Trans: progress label
            _("Determine server type"),
            # progress stage label
            _("Read firewall settings")
          ]
        ),
        Ops.add(
          # To translators: progress label %1 is filename
          Builtins.maplist(files) do |file|
            Builtins.sformat(_("Loading '%1'..."), file)
          end,
          [
            # Trans: progress label
            _("Determining running services..."),
            # Trans: progress label
            _("Determining server type..."),
            # progress step label
            _("Reading firewall settings..."),
            # Trans: progress label
            _("Done.")
          ]
        ),
        help
      )

      i = 0
      while Ops.less_than(i, Builtins.size(files))
        Progress.NextStage

        varfunc = Ops.get(vars, i)
        varfunc.call
        i = Ops.add(i, 1)
      end

      Progress.NextStage
      # "ypserv" is handled elsewhere
      @start_ypbind = Service.Enabled("ypbind")
      # Check if nis client is configured localy or not
      # -> client configuration should not be touched when it uses remote server
      if @start_ypbind
        Yast.import "Nis"
        Yast.import "DNS"
        Nis.Read
        remote = false
        Builtins.foreach(Builtins.splitstring(Nis.GetServers, " ")) do |server|
          remote = true if !DNS.IsHostLocal(server)
        end
        if remote ||
            Nis.policy != "" && !Builtins.issubstring(Nis.policy, "STATIC")
          @start_ypbind = false
          @nisclient_local = false
        end
      end

      @start_ypxfrd = Service.Enabled("ypxfrd")
      @start_yppasswdd = Service.Enabled("yppasswdd")

      # TODOm: fix like the client (?)
      if @domain == ""
        # a DHCP client may set the domainname too:
        # /etc/sysconfig/network/dhcp:DHCLIENT_SET_DOMAINNAME
        out = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), "/usr/bin/ypdomainname")
        )
        @domain = Builtins.deletechars(Ops.get_string(out, "stdout", ""), "\n")
      end
      @old_domainname = @domain

      # Check if any device one is configured with DHCP, to know if domain name
      # won't be replaced by dhcp (#28727)
      NetworkInterfaces.Read
      if Ops.greater_than(
          Builtins.size(NetworkInterfaces.Locate("BOOTPROTO", "dhcp")),
          0
        ) &&
          SCR.Read(
            path(".sysconfig.network.config.NETCONFIG_NIS_SETDOMAINNAME")
          ) != "no"
        @dhcp_changes_domain = true
      end

      Progress.NextStage
      if !isYPServerInstalled
        @ui_what = :none
      else
        @ui_what = isYPMaster ? :master : :slave
        #FIXME: this will give a hostname. the label says IP.
        master = getMaster
        @ui_master_ip = master if master != nil
      end

      Progress.NextStage

      Y2Firewall::Firewalld.instance.read

      Progress.NextStage

      @modified = false
      true
    end

    def SCRGet(p, default_val)
      default_val = deep_copy(default_val)
      v = SCR.Read(p)
      v != nil ? v : default_val
    end

    def SCRGetInt(p, default_val)
      v = SCR.Read(p)
      v != nil && v != "" && Ops.is_string?(v) ?
        Builtins.tointeger(Convert.to_string(v)) :
        default_val
    end
    def YPMakefileVars
      return if !FileUtils.Exists("/var/yp/Makefile")

      @maps = Convert.convert(
        SCRGet(
          path(".var.yp.makefile.maps"),
          ["passwd", "group", "rpc", "services", "netid"]
        ),
        :from => "any",
        :to   => "list <string>"
      )
      @minuid = SCRGetInt(path(".var.yp.makefile.MINUID"), 100)
      @mingid = SCRGetInt(path(".var.yp.makefile.MINGID"), 100)
      @merge_passwd = Convert.to_string(
        SCRGet(path(".var.yp.makefile.MERGE_PASSWD"), "true")
      ) == "true"
      @nopush = Convert.to_string(
        SCRGet(path(".var.yp.makefile.NOPUSH"), "true")
      ) == "true"

      nil
    end
    def YPServerVars
      if FileUtils.Exists("/etc/sysconfig/ypserv")
        @pwd_srcdir = Convert.to_string(
          SCRGet(path(".sysconfig.ypserv.YPPWD_SRCDIR"), "/etc")
        )
        @pwd_chfn = SCRGet(path(".sysconfig.ypserv.YPPWD_CHFN"), "no") == "yes"
        @pwd_chsh = SCRGet(path(".sysconfig.ypserv.YPPWD_CHSH"), "no") == "yes"
      end

      nil
    end
    def YPSystemVars
      @domain = Convert.to_string(SCRGet(path(".etc.defaultdomain"), "local"))

      nil
    end
    def YPSecurenets
      @securenets = [{ "network" => "127.0.0.0", "netmask" => "255.0.0.0" }]
      if FileUtils.Exists("/var/yp/securenets")
        @securenets = Convert.convert(
          SCRGet(path(".var.yp.securenets"), @securenets),
          :from => "any",
          :to   => "list <map>"
        )
      end

      nil
    end
    def YPServers
      if FileUtils.Exists("/var/yp/ypservers")
        @ypservers = Convert.convert(
          SCRGet(path(".var.yp.ypservers"), []),
          :from => "any",
          :to   => "list <string>"
        )
      end

      nil
    end

    # --------------------
    # read-routines

    # Gets the master server (name or IP?) from any of this server's maps
    # @return	nil if no map is found or it has no YP_MASTER_NAME
    def getMaster
      dn = @domain
      return nil if dn == ""
      ddir = Builtins.sformat("/var/yp/%1", dn)
      any_map = nil
      if Ops.greater_or_equal(SCR.Read(path(".target.size"), ddir), 0)
        dmaps = Convert.to_list(SCR.Read(path(".target.dir"), ddir))
        any_map = Ops.get_string(dmaps, 0)
      end
      return nil if any_map == nil
      command = Builtins.sformat(
        "/usr/lib/yp/makedbm -u /var/yp/%1/%2 | grep ^YP_MASTER_NAME",
        dn.shellescape,
        any_map.shellescape
      )

      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      l = Builtins.splitstring(Ops.get_string(out, "stdout", ""), " \t\n")
      Ops.get(l, 1)
    end

    # @return Determines if the current host is YP master or not
    def isYPMaster
      master = getMaster
      if master == nil
        return false # can't decide
      end

      output = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          "/usr/lib/yp/yphelper --hostname"
        )
      )
      yphelper_hostname = Ops.get_string(output, "stdout", "")

      master == Builtins.deletechars(yphelper_hostname, "\n")
    end

    # @return Checks if the YP server software is installed
    # by querying RPM for ypserv
    def isYPServerInstalled
      SCR.Execute(path(".target.bash"), "/usr/bin/rpm -q ypserv") == 0
    end

    # Adds an error to error_msg
    # @param [String] s message, ending with a newline
    def addError(s)
      @error_msg = Ops.add(@error_msg, s)

      nil
    end

    # Adds an error to error_details
    # @param [String] s message, ending with a newline
    def addErrorDetail(s)
      @error_details = Ops.add(
        @error_details,
        Builtins.sformat("<pre>%1</pre>", s)
      )

      nil
    end

    # Kind-of-compatible replacement for term evaluation.
    # Either f[0] is void(),
    # or f[0] is void(any) and f[1] is any
    # Not called, bug #37146
    def CallFunction01(f)
      f = deep_copy(f)
      fp = Ops.get(f, 0)
      if Ops.is(fp, "void ()")
        fp0 = Convert.convert(fp, :from => "any", :to => "void ()")
        fp0.call
      elsif Ops.is(fp, "void (any)")
        fp1 = Convert.convert(fp, :from => "any", :to => "void (any)")
        fp1.call(Ops.get(f, 1))
      else
        Builtins.y2error("Bad function type: %1", fp)
      end

      nil
    end

    # Write all NIS server settings
    # @return true on success
    def Write
      # help text 1/1
      help = _("<p>Please wait until the configuration is saved.</p>")
      # dialog heading
      title = _("Saving NIS server setup")
      progress_title = " "

      save_list = GetSaveList(@ui_what)
      step = 0

      # To translators: dialog title
      Progress.New(
        title,
        progress_title,
        Ops.add(Builtins.size(save_list), 1),
        Ops.add(
          Builtins.maplist(save_list) { |e| Ops.get_string(e, "save_label", "") },
          [
            # progress bar stage
            _("Save firewall settings")
          ]
        ),
        Ops.add(
          Builtins.maplist(save_list) do |e|
            Ops.get_string(e, "progress_label", "")
          end,
          [
            # progress step
            _("Saving firewall settings..."),
            # progress step
            _("Done.")
          ]
        ),
        help
      )

      Builtins.foreach(save_list) do |save_item|
        Progress.NextStage
        fl = Ops.get_list(save_item, "function", [])
        Builtins.y2debug("Calling: %1", fl)
        if Builtins.size(fl) == 1
          fp = Convert.convert(Ops.get(fl, 0), :from => "any", :to => "void ()")
          fp.call
        elsif Builtins.size(fl) == 2
          fp = Convert.convert(
            Ops.get(fl, 0),
            :from => "any",
            :to   => "void (any)"
          )
          fp.call(Ops.get(fl, 1))
        else
          Builtins.y2internal("Bad save list item %1", fl)
        end
      end

      Progress.NextStage

      Y2Firewall::Firewalld.instance.write

      Progress.NextStage
      true
    end

    # Removes file or directory and log errors
    # @param [Object] file what to remove
    def Remove(file)
      file = deep_copy(file)
      if SCR.Read(path(".target.size"), file) != -1
        output = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("/usr/bin/rm -rf %1", file.shellescape)
          )
        )
        if Ops.greater_than(
            Builtins.size(Ops.get_string(output, "stderr", "")),
            0
          )
          # To translators: message in the popup dialog
          addError(Builtins.sformat(_("Error while removing %1\n"), file))
          addErrorDetail(Ops.get_string(output, "stderr", ""))
        end
      end

      nil
    end

    # Ensures that the domain directory exists.
    # @param [String] directory	the path
    # @return			false if not and cannot be created
    def EnsureDirectory(directory)
      output = {}

      if SCR.Read(path(".target.size"), directory) == -1
        output = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("/usr/bin/mkdir %1", directory.shellescape)
          )
        )
        if Ops.greater_than(
            Builtins.size(Ops.get_string(output, "stderr", "")),
            0
          )
          # To translators: message in the popup dialog
          addError(
            Builtins.sformat(_("Directory %1 cannot be created.\n"), directory)
          )
          addErrorDetail(Ops.get_string(output, "stderr", ""))
          return false
        end
      end
      true
    end

    # Gets the YP maps from master for slave
    def YPGetMaps
      output = {}
      dn = @domain
      dndir = Builtins.sformat("/var/yp/%1", dn)
      # first make sure that the directory exists
      return if !EnsureDirectory(dndir)

      # and get the maps
      master = @ui_master_ip
      output = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "/usr/lib/yp/yphelper --maps %1 --domainname %2",
            master.shellescape,
            dn.shellescape
          )
        )
      )
      if Ops.get_integer(output, "exit", 1) != 0
        # To translators: message in the popup dialog
        addError(Builtins.sformat(_("Cannot get list of maps.\n")))
        addErrorDetail(Ops.get_string(output, "stderr", ""))
      end
      running_maps = Builtins.splitstring(
        Ops.get_string(output, "stdout", ""),
        "\n"
      )
      # the element after the last newline is empty, remove it
      if Ops.greater_than(Builtins.size(running_maps), 0)
        running_maps = Builtins.remove(
          running_maps,
          Ops.subtract(Builtins.size(running_maps), 1)
        )
      end

      Builtins.maplist(running_maps) do |map_name|
        output = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat(
              "/usr/lib/yp/ypxfr -f -h %1 -d %2 %3",
              master.shellescape,
              dn.shellescape,
              map_name.shellescape
            )
          )
        )
        if Ops.get_integer(output, "exit", 1) != 0
          # To translators: message in the popup dialog
          addError(
            Builtins.sformat(
              _("Error while retrieving %1 map from master.\n"),
              map_name
            )
          )
          addErrorDetail(Ops.get_string(output, "stderr", ""))
        end
      end


      if !Builtins.contains(running_maps, "ypservers")
        # To translators: message in the popup dialog
        addError(_("Could not get list with slaves.\n"))
      else
        output = Convert.to_map(
          SCR.Execute(
            path(".target.bash_output"),
            Builtins.sformat("/usr/lib/yp/makedbm -u %1/ypservers", dndir.shellescape)
          )
        )
        slaves = Ops.get_string(output, "stdout")

        if slaves != nil
          output = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              "/usr/lib/yp/yphelper --hostname"
            )
          )
          hostname = Builtins.deletechars(
            Ops.get_string(output, "stdout", ""),
            "\n"
          )
          failed = true
          Builtins.foreach(Builtins.splitstring(slaves, "\n")) do |line|
            lline = Builtins.splitstring(line, " \t")
            if Ops.get_string(lline, 0, "") == hostname &&
                Ops.get_string(lline, 1, "") == hostname
              failed = false
            end
          end
          if failed
            # To translators: message in the popup dialog, %1 is hostname
            addError(
              Builtins.sformat(
                _(
                  "Hostname of this host (%1)\nis not listed in the master's list.\n"
                ),
                hostname
              )
            )
          end
        end
      end

      nil
    end



    # Save securenets list

    def SaveSecurenets
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("/usr/bin/cp %1 %1.YaST2.save", "/var/yp/securenets")
      )
      if !SCR.Write(path(".var.yp.securenets"), @securenets)
        # To translators: message in the popup dialog
        addError(
          Builtins.sformat(_("Error saving file %1\n"), "/var/yp/securenets")
        )
      end

      nil
    end


    # Save list of slaves by calling appropriate any agent
    def SaveSlaves
      SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("/bin/cp %1 %1.YaST2.save", "/var/yp/ypservers")
      )
      if !SCR.Write(path(".var.yp.ypservers"), @ypservers)
        # To translators: message in the popup dialog
        addError(
          Builtins.sformat(_("Error saving file %1\n"), "/var/yp/ypservers")
        )
      end

      nil
    end

    # Saves config variables according to workflow
    # @param [Object] which workflow one of `slave, `master
    def SaveVariables(which)
      which = deep_copy(which)
      if !SCR.Write(path(".etc.defaultdomain"), @domain)
        # To translators: message in the popup dialog
        addError(_("Error setting up domain name\n"))
      end

      if which == :master
        settings = {
          ".sysconfig.ypserv.YPPWD_SRCDIR" => @pwd_srcdir,
          ".sysconfig.ypserv.YPPWD_CHFN"   => @pwd_chfn ? "yes" : "no",
          ".sysconfig.ypserv.YPPWD_CHSH"   => @pwd_chsh ? "yes" : "no",
          ".var.yp.makefile.maps"          => @maps,
          ".var.yp.makefile.MINUID"        => Builtins.sformat("%1", @minuid),
          ".var.yp.makefile.MINGID"        => Builtins.sformat("%1", @mingid),
          ".var.yp.makefile.MERGE_PASSWD"  => @merge_passwd ? "true" : "false",
          ".var.yp.makefile.NOPUSH"        => @nopush ? "true" : "false"
        }

        Builtins.maplist(settings) do |var, value|
          if !SCR.Write(Builtins.topath(var), value)
            var_parts = Builtins.splitstring(var, ".")
            var_name = Ops.get_string(
              var_parts,
              Ops.subtract(Builtins.size(var_parts), 1),
              ""
            )
            # To translators: message in the popup dialog
            addError(
              Builtins.sformat(_("Error setting up variable %1\n"), var_name)
            )
          end
        end

        if !SCR.Write(path(".sysconfig.ypserv"), nil)
          # To translators: message in the popup dialog
          addError(
            Builtins.sformat(
              _("Error saving file %1\n"),
              "/etc/sysconfig/ypserv"
            )
          )
        end
        if !SCR.Write(path(".var.yp.makefile"), nil)
          # To translators: message in the popup dialog
          addError(
            Builtins.sformat(_("Error saving file %1\n"), "/var/yp/Makefile")
          )
        end
      end

      nil
    end

    # Starts or stop daemons
    # @param [Object] workflow what to start or save: `master, `slave, `none
    def YPDaemons(workflow)
      workflow = deep_copy(workflow)
      output = {}
      to_stop = []
      to_start = []

      rpc_mapper = "portmap"
      rpc_mapper = "rpcbind" if Package.Installed("rpcbind")

      if workflow == :none
        to_stop = ["ypxfrd", "yppasswdd", "ypserv"]
      elsif workflow == :slave
        to_stop = ["ypxfrd", "yppasswdd", "ypserv"]
        to_start = [rpc_mapper, "ypserv"]
      elsif workflow == :master
        to_stop = ["ypxfrd", "yppasswdd", "ypserv"]
        to_start = [rpc_mapper, "ypserv"]

        to_start = Builtins.add(to_start, "yppasswdd") if @start_yppasswdd

        to_start = Builtins.add(to_start, "ypxfrd") if @start_ypxfrd
      end

      services = Builtins.listmap(to_stop) { |s| { s => "disable" } }
      Builtins.foreach(to_start) { |s| Ops.set(services, s, "enable") }
      Builtins.foreach(services) { |s, action| Service.Adjust(s, action) }

      Builtins.foreach(to_stop) do |d|
        Builtins.y2milestone("Stopping daemon %1", d)
        # $#@! broken by bug 9648
        ret = Service.RunInitScript(d, "stop")
        if ret != 0
          # To translators: message in the popup dialog
          addError(Builtins.sformat(_("Error while stopping %1 daemon\n"), d))
        end
      end

      Builtins.foreach(to_start) do |d|
        Builtins.y2milestone("Starting daemon %1", d)
        # start only if not running. essential for portmap! (bug #9999)
        if Service.Status(d) != 0
          ret = Service.RunInitScript(d, "start")
          if ret != 0
            # To translators: message in the popup dialog
            addError(Builtins.sformat(_("Error while starting %1 daemon\n"), d))
          end
        end
      end

      nil
    end

    # Creates initial database
    def YPMake
      output = {}

      # create the source directory, if it does not exist
      # (and passwd, shadow, group)

      return if !EnsureDirectory(@pwd_srcdir)
      create_ok = true
      Builtins.foreach(["passwd", "group"]) do |s|
        p2 = Ops.add(Ops.add(@pwd_srcdir, "/"), s)
        if Ops.less_than(SCR.Read(path(".target.size"), p2), 0)
          create_ok = create_ok &&
            0 ==
              SCR.Execute(
                path(".target.bash"),
                Builtins.sformat(
                  "/usr/bin/touch %1; /bin/chmod 0644 %1; /bin/chown root.root %1",
                  p2.shellescape
                )
              )
        end
      end
      p = Ops.add(@pwd_srcdir, "/shadow")
      if Ops.less_than(SCR.Read(path(".target.size"), p), 0)
        create_ok = create_ok &&
          0 ==
            SCR.Execute(
              path(".target.bash"),
              Builtins.sformat(
                "/usr/bin/touch %1; /bin/chmod 0640 %1; /bin/chown root.shadow %1",
                p.shellescape
              )
            )
      end

      if !create_ok
        # error popup
        addError(
          Builtins.sformat(_("Error while creating an empty user database.\n"))
        )
      end

      dn = @domain
      return if !EnsureDirectory(Builtins.sformat("/var/yp/%1", dn))

      output = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "/usr/bin/make -C /var/yp/%1 -f ../Makefile NOPUSH=true ypservers",
            dn.shellescape
          )
        )
      )

      if Ops.greater_than(
          Builtins.size(Ops.get_string(output, "stderr", "")),
          0
        )
        # To translators: message in the popup dialog
        addError(_("Error while creating the ypservers map.\n"))
        addErrorDetail(Ops.get_string(output, "stderr", ""))
      end

      output = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat(
            "/usr/bin/make -C /var/yp NOPUSH=true LOCALDOMAIN=%1",
            dn.shellescape
          )
        )
      )

      if Ops.greater_than(
          Builtins.size(Ops.get_string(output, "stderr", "")),
          0
        )
        # To translators: message in the popup dialog
        addError(_("Error while creating database.\n"))
        addErrorDetail(Ops.get_string(output, "stderr", ""))
      end

      nil
    end

    # Calls NIS client configuration writing
    def Client
      Yast.import "Nis"

      c = {
        "start_nis"   => @start_ypbind,
        "nis_domain"  => @domain,
        "nis_servers" => ["127.0.0.1"]
      }

      if @start_ypbind
        # static policy assures local client
        Ops.set(c, "netconfig_policy", "")
      end

      progress_orig = Progress.set(false)
      ok = Nis.Import(c) && Nis.Write
      Progress.set(progress_orig)
      if !ok
        # To translators: message in the popup dialog
        addError(_("Error while configuring the client.\n"))
        addErrorDetail(Nis.YpbindErrors)
      end

      nil
    end

    # Returns a list of what to save
    # @param [Symbol] workflow what workflow was chosen (`none, `slave, `master)
    # @return a list of maps: <pre>$[
    #   "save_label": ...,
    #   "progress_label": ...,
    #   "function": @see CallFunction01
    # ]</pre>
    def GetSaveList(workflow)
      result = []

      # do this remove for all workflows
      if @domain != ""
        result = [
          {
            # To translators: progress label
            "save_label"     => Builtins.sformat(
              _("Remove /var/yp/%1"),
              @domain
            ),
            # To translators: progress label
            "progress_label" => Builtins.sformat(
              _("Removing /var/yp/%1"),
              @domain
            ),
            "function"       => [
              fun_ref(method(:Remove), "void (any)"),
              Builtins.sformat("/var/yp/%1", @domain)
            ]
          }
        ]
      end

      # *** none YP server flow
      if workflow == :none
        result = Ops.add(
          result,
          [
            # To translators: progress label
            {
              "save_label"     => _("Stop running daemons."),
              # To translators: progress label
              "progress_label" => _(
                "Stopping running daemons."
              ),
              "function"       => [
                fun_ref(method(:YPDaemons), "void (any)"),
                :none
              ]
            }
          ]
        )
      # *** slave YP server flow
      elsif workflow == :slave
        result = Ops.add(
          result,
          [
            # To translators: progress label
            {
              "save_label"     => _("Get maps from master."),
              # To translators: progress label
              "progress_label" => _(
                "Getting maps from master."
              ),
              "function"       => [fun_ref(method(:YPGetMaps), "void ()")]
            },
            # To translators: progress label
            {
              "save_label"     => _("Save hosts allowed to query server."),
              # To translators: progress label
              "progress_label" => _(
                "Saving hosts allowed to query server."
              ),
              "function"       => [fun_ref(method(:SaveSecurenets), "void ()")]
            },
            # To translators: progress label
            {
              "save_label"     => _("Set config variables."),
              # To translators: progress label
              "progress_label" => _(
                "Setting config variables."
              ),
              "function"       => [
                fun_ref(method(:SaveVariables), "void (any)"),
                :slave
              ]
            },
            # To translators: progress label
            {
              "save_label"     => _("Start daemon."),
              # To translators: progress label
              "progress_label" => _(
                "Starting daemon."
              ),
              "function"       => [
                fun_ref(method(:YPDaemons), "void (any)"),
                :slave
              ]
            }
          ]
        )
      # *** master YP server flow
      elsif workflow == :master
        result = Ops.add(
          result,
          [
            # To translators: progress label
            {
              "save_label"     => _("Save hosts allowed to query server."),
              # To translators: progress label
              "progress_label" => _(
                "Saving hosts allowed to query server."
              ),
              "function"       => [fun_ref(method(:SaveSecurenets), "void ()")]
            }
          ]
        )

        if !@nopush && Ops.greater_than(Builtins.size(@ypservers), 0)
          result = Ops.add(
            result,
            [
              # To translators: progress label
              {
                "save_label"     => _("Save slaves."),
                # To translators: progress label
                "progress_label" => _(
                  "Saving slaves."
                ),
                "function"       => [fun_ref(method(:SaveSlaves), "void ()")]
              }
            ]
          )
        end
        result = Ops.add(
          result,
          [
            # To translators: progress label
            {
              "save_label"     => _("Set config variables."),
              # To translators: progress label
              "progress_label" => _(
                "Setting config variables."
              ),
              "function"       => [
                fun_ref(method(:SaveVariables), "void (any)"),
                :master
              ]
            },
            # To translators: progress label
            {
              "save_label"     => _("Start daemons."),
              # To translators: progress label
              "progress_label" => _(
                "Starting daemons."
              ),
              "function"       => [
                fun_ref(method(:YPDaemons), "void (any)"),
                :master
              ]
            },
            # To translators: progress label
            {
              "save_label"     => _("Create initial database."),
              # To translators: progress label
              "progress_label" => _(
                "Creating database."
              ),
              "function"       => [fun_ref(method(:YPMake), "void ()")]
            }
          ]
        )
      end

      # slave or master is also client ?
      if Builtins.contains([:slave, :master], workflow)
        if @start_ypbind
          result = Ops.add(
            result,
            [
              # To translators: progress label
              {
                "save_label"     => _("Start NIS client."),
                # To translators: progress label
                "progress_label" => _(
                  "Starting NIS client."
                ),
                "function"       => [fun_ref(method(:Client), "void ()")]
              }
            ]
          )
        elsif @nisclient_local
          result = Ops.add(
            result,
            [
              # To translators: progress label
              {
                "save_label"     => _("Stop NIS client."),
                # To translators: progress label
                "progress_label" => _(
                  "Stopping NIS client."
                ),
                "function"       => [fun_ref(method(:Client), "void ()")]
              }
            ]
          )
        end
      end

      deep_copy(result)
    end

    # ----------------------------------------
    # autoyast

    # Get all nisServer settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      # Get default variables


      type = Ops.get_string(settings, "server_type", "none")
      if type == "master"
        @ui_what = :master
      elsif type == "slave"
        @ui_what = :slave
      else
        @ui_what = :none
      end

      @domain = Ops.get_string(settings, "domain", "")
      @minuid = Ops.get_integer(settings, "minuid", 0)
      @mingid = Ops.get_integer(settings, "mingid", 0)

      @merge_passwd = Ops.get_boolean(settings, "merge_passwd", false)

      @ypservers = Ops.get_list(settings, "slaves", [])
      YPServers() if @ypservers == []

      @start_ypbind = Ops.get_boolean(settings, "start_ypbind", false)

      @start_ypxfrd = Ops.get_boolean(settings, "start_ypxfrd", false)
      @start_yppasswdd = Ops.get_boolean(settings, "start_yppasswdd", false)


      @maps = Ops.get_list(settings, "maps_to_serve", [])
      YPMakefileVars() if @maps == []

      @pwd_srcdir = Ops.get_string(settings, "pwd_srcdir", "/etc")
      @pwd_chsh = Ops.get_boolean(settings, "pwd_chsh", false)
      @pwd_chfn = Ops.get_boolean(settings, "pwd_chfn", false)
      @nopush = Ops.get_boolean(settings, "nopush", false)

      @securenets = Ops.get_list(settings, "securenets", [])
      YPSecurenets() if @securenets == []

      true
    end

    # Dump the nisServer settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      # TODO FIXME: your code here (return the above mentioned variables)...
      settings = {}
      Ops.set(settings, "domain", @domain)


      type = "none"
      if @ui_what == :master
        type = "master"
      elsif @ui_what == :slave
        type = "slave"
      end

      Ops.set(settings, "server_type", type)
      Ops.set(settings, "minuid", @minuid)
      Ops.set(settings, "mingid", @mingid)
      Ops.set(settings, "merge_passwd", @merge_passwd)

      slaves = []
      slaves = deep_copy(@ypservers)

      # FIXME: NI
      # global boolean start_ypbind = false;

      Ops.set(settings, "start_ypbind", @start_ypbind)

      Ops.set(settings, "start_ypxfrd", @start_ypxfrd)
      Ops.set(settings, "start_yppasswdd", @start_yppasswdd)

      Ops.set(settings, "maps_to_serve", @maps)

      Ops.set(settings, "pwd_srcdir", @pwd_srcdir)
      Ops.set(settings, "slaves", slaves)
      Ops.set(settings, "pwd_chsh", @pwd_chsh)
      Ops.set(settings, "pwd_chfn", @pwd_chfn)
      Ops.set(settings, "nopush", @nopush)
      Ops.set(settings, "securenets", @securenets)
      deep_copy(settings)
    end

    # Create a textual summary and a list of unconfigured cards
    # @param split split configured and unconfigured?
    # @return summary of the current configuration
    def Summary
      summary = ""
      nc = Summary.NotConfigured
      summary = Summary.AddHeader(summary, _("NIS Domain"))
      summary = Summary.AddLine(summary, @domain != "" ? @domain : nc)



      [summary, []]
    end

    publish :variable => :modified, :type => "boolean"
    publish :function => :SetModified, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :variable => :write_only, :type => "boolean"
    publish :variable => :domain, :type => "string"
    publish :variable => :old_domainname, :type => "string"
    publish :variable => :ui_what, :type => "symbol"
    publish :variable => :ui_master_ip, :type => "string"
    publish :variable => :maps, :type => "list <string>"
    publish :variable => :minuid, :type => "integer"
    publish :variable => :mingid, :type => "integer"
    publish :variable => :merge_passwd, :type => "boolean"
    publish :variable => :nopush, :type => "boolean"
    publish :variable => :ypservers, :type => "list <string>"
    publish :variable => :securenets, :type => "list <map>"
    publish :variable => :start_ypbind, :type => "boolean"
    publish :variable => :nisclient_local, :type => "boolean"
    publish :variable => :start_ypxfrd, :type => "boolean"
    publish :variable => :start_yppasswdd, :type => "boolean"
    publish :variable => :pwd_srcdir, :type => "string"
    publish :variable => :pwd_chfn, :type => "boolean"
    publish :variable => :pwd_chsh, :type => "boolean"
    publish :variable => :dhcp_changes_domain, :type => "boolean"
    publish :variable => :required_packages, :type => "list <string>"
    publish :function => :isYPMaster, :type => "boolean ()"
    publish :function => :isYPServerInstalled, :type => "boolean ()"
    publish :function => :getMaster, :type => "string ()"
    publish :function => :GetSaveList, :type => "list <map> (symbol)"
    publish :function => :GetAllMaps, :type => "list <string> ()"
    publish :function => :Read, :type => "boolean ()"
    publish :variable => :error_msg, :type => "string"
    publish :variable => :error_details, :type => "string"
    publish :function => :addError, :type => "void (string)"
    publish :function => :addErrorDetail, :type => "void (string)"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Remove, :type => "void (any)"
    publish :function => :EnsureDirectory, :type => "boolean (string)"
    publish :function => :YPGetMaps, :type => "void ()"
    publish :function => :SaveSecurenets, :type => "void ()"
    publish :function => :SaveSlaves, :type => "void ()"
    publish :function => :SaveVariables, :type => "void (any)"
    publish :function => :YPDaemons, :type => "void (any)"
    publish :function => :YPMake, :type => "void ()"
    publish :function => :Client, :type => "void ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :Summary, :type => "list ()"
  end

  NisServer = NisServerClass.new
  NisServer.main
end
