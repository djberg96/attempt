require 'safe_timeout'
require 'structured_warnings'

# The Attempt class encapsulates methods related to multiple attempts at
# running the same method before actually failing.
class Attempt

  # The version of the attempt library.
  VERSION = '0.5.1'.freeze

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
  #    Attempt.new(**kwargs)
  #
  # Creates and returns a new +Attempt+ object. The supported keyword options
  # are as follows:
  #
  # * tries     - The number of attempts to make before giving up. The default is 3.
  # * interval  - The delay in seconds between each attempt. The default is 60.
  # * log       - An IO handle or Logger instance where warnings/errors are logged to. The default is nil.
  # * increment - The amount to increment the interval between tries. The default is 0.
  # * level     - The level of exception to be caught. The default is everything, i.e. Exception.
  # * warnings  - Boolean value that indicates whether or not errors are treated as warnings
  #               until the maximum number of attempts has been made. The default is true.
  # * timeout   - Boolean value to indicate whether or not to automatically wrap your
  #               proc in a SafeTimeout block. The default is false.
  #
  # Example:
  #
  #   a = Attempt.new(tries: 5, increment: 10, timeout: true)
  #   a.attempt{ http.get("http://something.foo.com") }
  #
  def initialize(**options)
    @tries     = options[:tries] || 3         # Reasonable default
    @interval  = options[:interval] || 60     # Reasonable default
    @log       = options[:log]                # Should be an IO handle, if provided
    @increment = options[:increment] || 0     # Should be an integer, if provided
    @timeout   = options[:timeout] || false   # Wrap the code in a timeout block if provided
    @level     = options[:level] || Exception # Level of exception to be caught
    @warnings  = options[:warnings] || true   # Errors are sent to STDERR as warnings if true
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
        SafeTimeout.timeout(@timeout){ yield }
      else
        yield
      end
    rescue @level => error
      @tries -= 1
      if @tries > 0
        msg = "Error on attempt # #{count}: #{error}; retrying"
        count += 1
        warn Warning, msg if @warnings

        if @log # Accept an IO or Logger object
          @log.respond_to?(:puts) ? @log.puts(msg) : @log.warn(msg)
        end

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
   #    attempt(tries: 3, interval: 60, timeout: 10){ # some op }
   #
   # Attempt to perform the operation in the provided block up to +tries+
   # times, sleeping +interval+ between each try. By default the number
   # of tries defaults to 3, the interval defaults to 60 seconds, and there
   # is no timeout specified.
   #
   # If +timeout+ is provided then the operation is wrapped in a Timeout
   # block as well. This is handy for those rare occasions when an IO
   # connection could hang indefinitely, for example.
   #
   # If the operation still fails the (last) error is then re-raised.
   #
   # This is really just a convenient wrapper for Attempt.new + Attempt#attempt.
   #
   # Example:
   #
   #    # Make 3 attempts to connect to the database, 60 seconds apart.
   #    attempt{ DBI.connect(dsn, user, passwd) }
   #
   def attempt(**kwargs, &block)
     object = Attempt.new(kwargs)
     object.attempt(&block)
   end
end
