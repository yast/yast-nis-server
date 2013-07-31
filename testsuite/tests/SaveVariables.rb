# encoding: utf-8

# YaST2: Modules testsuite
#
# Description:
#   Testsuite for the SaveVariables function
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class SaveVariablesClient < Client
    def main
      # testedfiles: NisServer.ycp Service.ycp Report.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ_INIT = { "target" => { "size" => 0 } }
      @EXEC_INIT = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ_INIT, {}, @EXEC_INIT], nil)

      Yast.import "NisServer"
      Yast.include self, "nis_server/routines.rb"

      NisServer.start_ypbind = true
      NisServer.domain = "thedomain"
      NisServer.pwd_srcdir = "/etc"
      NisServer.merge_passwd = true

      DUMP("slave")
      TEST(lambda { NisServer.SaveVariables(:slave) }, [], true)
      DUMP("master")
      TEST(lambda { NisServer.SaveVariables(:master) }, [], true)

      nil
    end
  end
end

Yast::SaveVariablesClient.new.main
