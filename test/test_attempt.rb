#####################################################################
# test_attempt.rb
#
# Test case for the attempt library. You should run this test case
# via the 'rake test' Rakefile task.
#
# TODO: Test that an Attempt::Warning is raised.
#####################################################################
require 'test-unit'
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
    $value    = 0
  end

  test "version constant is set to expected value" do
    assert_equal('0.2.1', Attempt::VERSION)
  end

  test "attempt works as expected without arguments" do
    assert_nothing_raised{ attempt{ 2 + 2 } }
  end

  test "attempt retries the number of times specified" do
    assert_nothing_raised{ attempt(@tries){ $value += 1; raise if $value < 2 } }
    assert_equal(2, $value)
  end

  test "attempt retries the number of times specified with interval" do
    assert_nothing_raised{ attempt(@tries, @interval){ $value += 1; raise if $value < 2 } }
  end

  test "attempt retries the number of times specified with interval and timeout" do
    assert_nothing_raised{ attempt(@tries, @interval, @timeout){ $value += 1; raise if $value < 2 } }
  end

  test "attempt raises a timeout error if timeout value is exceeded" do
    assert_raises(Timeout::Error){ attempt(1, 1, @timeout){ sleep 5 } }
  end

  test "attempt raises exception as expected" do
    assert_raises(RuntimeError){ attempt(2, 2){ raise } }
  end

  def teardown
    @tries    = nil
    @interval = nil
    @timeout  = nil
    $value    = 0
  end

  def self.shutdown
    $stderr = STDERR
  end
end
