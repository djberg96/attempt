#####################################################################
# attempt_spec.rb
#
# Tests for the attempt library. You should run this test case via
# the 'rake test' Rakefile task (or just 'rake').
#
# TODO: Test that an Attempt::Warning is raised.
#####################################################################
require 'rspec'
require 'attempt'
require 'stringio'

RSpec.describe Attempt do
  before(:all) do
    $stderr = StringIO.new
  end

  before do
    @tries    = 2
    @interval = 0.1
    @timeout  = 0.1
    $value    = 0
  end

  example "version constant is set to expected value" do
    expect(Attempt::VERSION).to eq('0.6.1')
    expect(Attempt::VERSION).to be_frozen
  end

  example "attempt works as expected without arguments" do
    expect{ attempt{ 2 + 2 } }.not_to raise_error
  end

  example "attempt retries the number of times specified" do
    expect{ attempt(tries: @tries){ $value += 1; raise if $value < 2 } }.not_to raise_error
    expect($value).to eq(2)
  end

  example "attempt retries the number of times specified with interval" do
    expect{
      attempt(tries: @tries, interval: @interval){ $value += 1; raise if $value < 2 }
    }.not_to raise_error
    expect($value).to eq(2)
  end

  example "attempt retries the number of times specified with interval and timeout" do
    expect{
      attempt(tries: @tries, interval: @interval, timeout: @timeout){ $value += 1; raise if $value < 2 }
    }.not_to raise_error
  end

  example "attempt raises a timeout error if timeout value is exceeded" do
    expect{ attempt(tries: 1, interval: 1, timeout: @timeout){ sleep 5 } }.to raise_error(Timeout::Error)
  end

  example "attempt raises exception as expected" do
    expect{ attempt(tries: 2, interval: 2){ raise } }.to raise_error(RuntimeError)
  end

  after do
    $after = 0
  end

  after(:all) do
    $stderr = STDERR
  end
end
