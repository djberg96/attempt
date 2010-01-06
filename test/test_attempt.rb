#####################################################################
# test_attempt.rb
#
# Test case for the attempt library. You should run this test case
# via the 'rake test' Rakefile task.
#
# TODO: Test that an Attempt::Warning is raised.
#####################################################################
require 'rubygems'
gem 'test-unit'

require 'test/unit'
require 'attempt'
require 'stringio'

class TC_Attempt < Test::Unit::TestCase
   def self.startup
      $stderr = StringIO.new
   end

   def setup
      @tries    = 2
      @interval = 0.1
      @timeout  = 0.1
   end
   
   def test_version
      assert_equal('0.2.0', Attempt::VERSION)
   end
   
   def test_attempt_basic
      assert_nothing_raised{ attempt{ 2 + 2 } }
      assert_nothing_raised{ attempt(@tries){ 2 + 2 } }
      assert_nothing_raised{ attempt(@tries, @interval){ 2 + 2 } }
      assert_nothing_raised{ attempt(@tries, @interval, @timeout){ 2 + 2 } }
   end

   def test_attempt_expected_errors
      assert_raises(Timeout::Error){ attempt(1, 1, @timeout){ sleep 5 } }
      assert_raises(RuntimeError){ attempt(2, 2){ raise } }
   end
   
   def teardown
      @tries    = nil
      @interval = nil
      @timeout  = nil
   end

   def self.shutdown
      $stderr = STDERR
   end
end
