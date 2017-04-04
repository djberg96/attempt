require 'timeout'
require 'structured_warnings'

# The Attempt class encapsulates methods related to multiple attempts at
# running the same method before actually failing.
class Attempt

  # The version of the attempt library.
  VERSION = '0.3.1'.freeze

  # Warning raised if an attempt fails before the maximum number of tries
  # has been reached.
  class Warning < StructuredWarnings::StandardWarning; end

  # Number of attempts to make before failing. The default is 3.
  attr_accessor :tries

  # Number of seconds to wait between attempts. The default is 60.
  attr_accessor :interval

  # A boolean value that determines whether errors that would have been
  # raised should be sent to STDERR as warnings. The default is true.
  attr_accessor :warnings

  # If you provide an IO handle to this option then errors that would
  # have been raised are sent to that handle.
  attr_accessor :log

  # If set, this increments the interval with each failed attempt by that
  # number of seconds.
  attr_accessor :increment

  # If set, the code block is further wrapped in a timeout block.
  attr_accessor :timeout

  # Determines which exception level to check when looking for errors to
  # retry.  The default is 'Exception' (i.e. all errors).
  attr_accessor :level

  # :call-seq:
  #    Attempt.new{ |a| ... }
  #
  # Creates and returns a new +Attempt+ object.  Use a block to set the
  # accessors.
  #
  def initialize
    @tries     = 3         # Reasonable default
    @interval  = 60        # Reasonable default
    @log       = nil       # Should be an IO handle, if provided
    @increment = nil       # Should be an int, if provided
    @timeout   = nil       # Wrap the code in a timeout block if provided
    @level     = Exception # Level of exception to be caught
    @warnings  = true      # Errors are sent to STDERR as warnings if true

    yield self if block_given?
  end

  # Attempt to perform the operation in the provided block up to +tries+
  # times, sleeping +interval+ between each try.
  #
  # You will not typically use this method directly, but the Kernel#attempt
  # method instead.
  #
  def attempt
    count = 1
    begin
      if @timeout
        Timeout.timeout(@timeout){ yield }
      else
        yield
      end
    rescue @level => error
      @tries -= 1
      if @tries > 0
        msg = "Error on attempt # #{count}: #{error}; retrying"
        count += 1
        warn Warning, msg if @warnings
        @log.puts msg if @log
        @interval += @increment if @increment
        sleep @interval
        retry
      end
      raise
    end
  end
end

module Kernel
   # :call-seq:
   #    attempt(tries = 3, interval = 60, timeout = nil){ # some op }
   #
   # Attempt to perform the operation in the provided block up to +tries+
   # times, sleeping +interval+ between each try.  By default the number
   # of tries defaults to 3, the interval defaults to 60 seconds, and there
   # is no timeout specified.
   #
   # If +timeout+ is provided then the operation is wrapped in a Timeout
   # block as well.  This is handy for those rare occasions when an IO
   # connection could hang indefinitely, for example.
   #
   # If the operation still fails the (last) error is then re-raised.
   #
   # This is really just a wrapper for Attempt.new where the simple case is
   # good enough i.e. you don't care about warnings, increments or logging,
   # and you want a little added convenience.
   #
   # Example:
   #
   #    # Make 3 attempts to connect to the database, 60 seconds apart.
   #    attempt{ DBI.connect(dsn, user, passwd) }
   #
   def attempt(tries = 3, interval = 60, timeout = nil, &block)
      raise 'no block given' unless block_given?
      Attempt.new{ |a|
        a.tries    = tries
        a.interval = interval
        a.timeout  = timeout if timeout
      }.attempt(&block)
   end
end
