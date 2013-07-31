# encoding: utf-8

# YaST2: Modules testsuite
#
# Description:
#   Testsuite for the routines.ycp include
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#
# $Id$
module Yast
  class RoutinesClient < Client
    def main
      # testedfiles: routines.ycp NisServer.ycp Testsuite.ycp

      Yast.include self, "testsuite.rb"

      @READ_INIT = { "target" => { "size" => 0 } }
      @EXEC_INIT = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ_INIT, {}, @EXEC_INIT], nil)

      Yast.import "NisServer"
      Yast.include self, "nis_server/routines.rb"

      # converts values to boolean
      TEST(lambda { toboolean("true") }, [], nil)
      TEST(lambda { toboolean("false") }, [], nil)
      TEST(lambda { toboolean(1) }, [], nil)
      TEST(lambda { toboolean(0) }, [], nil)
      TEST(lambda { toboolean(true) }, [], nil)
      TEST(lambda { toboolean(false) }, [], nil)

      # all other values are false
      TEST(lambda { toboolean([]) }, [], nil)
      TEST(lambda { toboolean({}) }, [], nil)
      TEST(lambda { toboolean(nil) }, [], nil)
      TEST(lambda { toboolean(:symbol) }, [], nil)

      DUMP("getMaster")
      # no domain
      NisServer.domain = ""
      TEST(lambda { NisServer.getMaster }, [], nil)
      # no map dir
      NisServer.domain = "testdomain"
      TEST(lambda { NisServer.getMaster }, [], -1) # .target.size
      # no maps in dir
      @READ = { "target" => { "size" => 42, "dir" => [] } }
      TEST(lambda { NisServer.getMaster }, [@READ], nil)
      # no master entry in map
      @READ = { "target" => { "size" => 42, "dir" => ["map1", "map2"] } }
      @EXECFAIL = {
        "target" => {
          "bash_output" => { "exit" => 1, "stdout" => "", "stderr" => "" }
        }
      }
      TEST(lambda { NisServer.getMaster }, [@READ, {}, @EXECFAIL], nil)
      # all ok
      @EXEC1 = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "YP_MASTER_NAME nismaster.foo.com\n",
            "stderr" => ""
          }
        }
      }
      TEST(lambda { NisServer.getMaster }, [@READ, {}, @EXEC1], nil)

      # this test depends on the values of READ, EXEC1 and EXECFAIL set above!
      DUMP("isYPMaster")
      # failure
      TEST(lambda { NisServer.isYPMaster }, [@READ, {}, [@EXEC1, @EXECFAIL]], nil)
      # not a master
      @EXEC2 = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "nisslave.foo.com\n",
            "stderr" => ""
          }
        }
      }
      TEST(lambda { NisServer.isYPMaster }, [@READ, {}, [@EXEC1, @EXEC2]], nil)
      # master
      @EXEC2 = {
        "target" => {
          "bash_output" => {
            "exit"   => 0,
            "stdout" => "nismaster.foo.com\n",
            "stderr" => ""
          }
        }
      }
      TEST(lambda { NisServer.isYPMaster }, [@READ, {}, [@EXEC1, @EXEC2]], nil)

      nil
    end
  end
end

Yast::RoutinesClient.new.main
