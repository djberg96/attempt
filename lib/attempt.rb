# frozen_string_literal: true

require 'timeout'

# Try to require safe_timeout for non-Windows systems, fall back to timeout if not available
begin
  require 'safe_timeout' unless File::ALT_SEPARATOR
rescue LoadError
  # safe_timeout not available, will use standard timeout
  SafeTimeout = Timeout if defined?(Timeout)
end

require 'structured_warnings'

# The Attempt class encapsulates methods related to multiple attempts at
# running the same method before actually failing.
class Attempt
  # The version of the attempt library.
  VERSION = '0.6.3'

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
  # * tries     - The number of attempts to make before giving up. Must be positive. The default is 3.
  # * interval  - The delay in seconds between each attempt. Must be non-negative. The default is 60.
  # * log       - An IO handle or Logger instance where warnings/errors are logged to. The default is nil.
  # * increment - The amount to increment the interval between tries. Must be non-negative. The default is 0.
  # * level     - The level of exception to be caught. The default is StandardError (recommended over Exception).
  # * warnings  - Boolean value that indicates whether or not errors are treated as warnings
  #               until the maximum number of attempts has been made. The default is true.
  # * timeout   - Timeout in seconds to automatically wrap your proc in a Timeout block.
  #               Must be positive if provided. The default is nil (no timeout).
  #
  # Example:
  #
  #   a = Attempt.new(tries: 5, increment: 10, timeout: 30)
  #   a.attempt{ http.get("http://something.foo.com") }
  #
  # Raises ArgumentError if any parameters are invalid.
  #
  def initialize(**options)
    @tries     = validate_tries(options[:tries] || 3)
    @interval  = validate_interval(options[:interval] || 60)
    @log       = validate_log(options[:log])
    @increment = validate_increment(options[:increment] || 0)
    @timeout   = validate_timeout(options[:timeout])
    @level     = options[:level] || StandardError  # More appropriate default than Exception
    @warnings  = options.fetch(:warnings, true)    # More explicit than ||

    freeze_configuration if options[:freeze_config]
  end

  # Attempt to perform the operation in the provided block up to +tries+
  # times, sleeping +interval+ between each try.
  #
  # You will not typically use this method directly, but the Kernel#attempt
  # method instead.
  #
  # Returns the result of the block if successful.
  # Raises the last caught exception if all attempts fail.
  #
  def attempt(&block)
    raise ArgumentError, 'No block given' unless block_given?

    attempts_made = 0
    current_interval = @interval
    max_tries = @tries

    begin
      attempts_made += 1

      result = if timeout_enabled?
        execute_with_timeout(&block)
      else
        yield
      end

      return result

    rescue @level => err
      remaining_tries = max_tries - attempts_made

      if remaining_tries > 0
        log_retry_attempt(attempts_made, err)
        sleep current_interval if current_interval > 0
        current_interval += @increment if @increment && @increment > 0
        retry
      else
        log_final_failure(attempts_made, err)
        raise
      end
    end
  end

  # Returns true if this attempt instance has been configured to use timeouts
  def timeout_enabled?
    !@timeout.nil? && @timeout != false
  end

  # Returns the effective timeout value (handles both boolean and numeric values)
  def effective_timeout
    return nil unless timeout_enabled?
    @timeout.is_a?(Numeric) ? @timeout : 10  # Default timeout if true was passed
  end

  # Returns a summary of the current configuration
  def configuration
    {
      tries: @tries,
      interval: @interval,
      increment: @increment,
      timeout: @timeout,
      level: @level,
      warnings: @warnings,
      log: @log&.class&.name
    }
  end

  private

  # Execute the block with appropriate timeout mechanism
  def execute_with_timeout(&block)
    timeout_value = effective_timeout
    return yield unless timeout_value

    if File::ALT_SEPARATOR || !defined?(SafeTimeout)
      Timeout.timeout(timeout_value, &block)
    else
      SafeTimeout.timeout(timeout_value, &block)
    end
  end

  # Log retry attempt information
  def log_retry_attempt(attempt_number, error)
    msg = "Attempt #{attempt_number} failed: #{error.class}: #{error.message}; retrying"

    warn Warning, msg if @warnings
    log_message(msg)
  end

  # Log final failure information
  def log_final_failure(total_attempts, error)
    msg = "All #{total_attempts} attempts failed. Final error: #{error.class}: #{error.message}"
    log_message(msg)
  end

  # Helper method to handle logging to various output types
  def log_message(message)
    return unless @log

    if @log.respond_to?(:warn)
      @log.warn(message)
    elsif @log.respond_to?(:puts)
      @log.puts(message)
    elsif @log.respond_to?(:write)
      @log.write("#{message}\n")
    end
  end

  # Validation methods for better error handling
  def validate_tries(tries)
    unless tries.is_a?(Integer) && tries > 0
      raise ArgumentError, "tries must be a positive integer, got: #{tries.inspect}"
    end
    tries
  end

  def validate_interval(interval)
    unless interval.is_a?(Numeric) && interval >= 0
      raise ArgumentError, "interval must be a non-negative number, got: #{interval.inspect}"
    end
    interval
  end

  def validate_increment(increment)
    unless increment.is_a?(Numeric) && increment >= 0
      raise ArgumentError, "increment must be a non-negative number, got: #{increment.inspect}"
    end
    increment
  end

  def validate_timeout(timeout)
    return nil if timeout.nil?
    return false if timeout == false

    unless timeout.is_a?(Numeric) && timeout > 0
      raise ArgumentError, "timeout must be a positive number or nil, got: #{timeout.inspect}"
    end
    timeout
  end

  def validate_log(log)
    return nil if log.nil?

    unless log.respond_to?(:puts) || log.respond_to?(:warn) || log.respond_to?(:write)
      raise ArgumentError, "log must respond to :puts, :warn, or :write methods"
    end
    log
  end

  def freeze_configuration
    instance_variables.each { |var| instance_variable_get(var).freeze }
    freeze
  end
end

# Extend the Kernel module with a simple interface for the Attempt class.
module Kernel
  # :call-seq:
  #    attempt(tries: 3, interval: 60, timeout: 10, **options){ # some op }
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
  # All options supported by Attempt.new are also supported here.
  #
  # Example:
  #
  #    # Make 3 attempts to connect to the database, 60 seconds apart.
  #    attempt{ DBI.connect(dsn, user, passwd) }
  #
  #    # Make 5 attempts with exponential backoff
  #    attempt(tries: 5, interval: 1, increment: 2) { risky_operation }
  #
  def attempt(**kwargs, &block)
    raise ArgumentError, 'No block given' unless block_given?

    object = Attempt.new(**kwargs)
    object.attempt(&block)
  end
end
