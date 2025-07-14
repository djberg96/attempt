# frozen_string_literal: true

require 'timeout'
require 'structured_warnings'

# Custom timeout implementation that's more reliable than Ruby's Timeout module
class AttemptTimeout
  class Error < StandardError; end

  # More reliable timeout using Thread + sleep instead of Timeout.timeout
  # This approach is safer as it doesn't use Thread#raise
  def self.timeout(seconds, &block)
    return yield if seconds.nil? || seconds <= 0

    result = nil
    exception = nil

    thread = Thread.new do
      begin
        result = yield
      rescue => e
        exception = e
      end
    end

    if thread.join(seconds)
      # Thread completed within timeout
      raise exception if exception
      result
    else
      # Thread timed out
      thread.kill  # More graceful than Thread#raise
      thread.join  # Wait for cleanup
      raise Error, "execution expired after #{seconds} seconds"
    end
  end

  # Alternative: Fiber-based timeout (even more lightweight)
  def self.fiber_timeout(seconds, &block)
    return yield if seconds.nil? || seconds <= 0

    fiber = Fiber.new(&block)
    start_time = Time.now

    loop do
      if Time.now - start_time > seconds
        raise Error, "execution expired after #{seconds} seconds"
      end

      begin
        result = fiber.resume
        return result if fiber.dead?
      rescue FiberError
        # Fiber is dead, return last result
        break
      end

      # Small sleep to prevent busy waiting
      sleep 0.001
    end
  end
end

# The Attempt class encapsulates methods related to multiple attempts at
# running the same method before actually failing.
class Attempt
  # The version of the attempt library.
  VERSION = '0.7.0'

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

  # Strategy to use for timeout implementation
  # Options: :custom, :thread, :process, :ruby_timeout
  attr_accessor :timeout_strategy

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
  # * timeout_strategy - Strategy for timeout implementation. Options: :auto (default), :custom, :thread, :process, :ruby_timeout
  #
  # Example:
  #
  #   a = Attempt.new(tries: 5, increment: 10, timeout: 30, timeout_strategy: :process)
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
    @timeout_strategy = options[:timeout_strategy] || :auto
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
      timeout_strategy: @timeout_strategy,
      level: @level,
      warnings: @warnings,
      log: @log&.class&.name
    }
  end

  private

  # Execute the block with appropriate timeout mechanism
  # Uses multiple strategies for better reliability
  def execute_with_timeout(&block)
    timeout_value = effective_timeout
    return yield unless timeout_value

    case @timeout_strategy
    when :custom
      execute_with_custom_timeout(timeout_value, &block)
    when :thread
      execute_with_thread_timeout(timeout_value, &block)
    when :process
      execute_with_process_timeout(timeout_value, &block)
    when :ruby_timeout
      Timeout.timeout(timeout_value, &block)
    else  # :auto
      execute_with_auto_timeout(timeout_value, &block)
    end
  end

  # Automatic timeout strategy selection
  def execute_with_auto_timeout(timeout_value, &block)
    # Try custom timeout first (most reliable)
    begin
      return execute_with_custom_timeout(timeout_value, &block)
    rescue NameError, NoMethodError
      # Fall back to other strategies
      execute_with_fallback_timeout(timeout_value, &block)
    end
  end

  # Custom timeout using our AttemptTimeout class
  def execute_with_custom_timeout(timeout_value, &block)
    begin
      return AttemptTimeout.timeout(timeout_value, &block)
    rescue AttemptTimeout::Error => e
      raise Timeout::Error, e.message  # Convert to expected exception type
    end
  end

  # Fallback timeout implementation using multiple strategies
  def execute_with_fallback_timeout(timeout_value, &block)
    # Strategy 2: Process-based timeout (most reliable for blocking operations)
    if respond_to?(:system) && !defined?(RUBY_ENGINE) || RUBY_ENGINE != 'jruby'
      return execute_with_process_timeout(timeout_value, &block)
    end

    # Strategy 3: Thread-based timeout with better error handling
    return execute_with_thread_timeout(timeout_value, &block)
  rescue
    # Strategy 4: Last resort - use Ruby's Timeout (least reliable)
    Timeout.timeout(timeout_value, &block)
  end

  # Process-based timeout - most reliable for I/O operations
  def execute_with_process_timeout(timeout_value, &block)
    reader, writer = IO.pipe

    pid = fork do
      reader.close
      begin
        result = yield
        Marshal.dump(result, writer)
      rescue => e
        Marshal.dump({error: e}, writer)
      ensure
        writer.close
      end
    end

    writer.close

    if Process.waitpid(pid, Process::WNOHANG)
      # Process completed immediately
      result = Marshal.load(reader)
    else
      # Wait for timeout
      if IO.select([reader], nil, nil, timeout_value)
        Process.waitpid(pid)
        result = Marshal.load(reader)
      else
        Process.kill('TERM', pid)
        Process.waitpid(pid)
        raise Timeout::Error, "execution expired after #{timeout_value} seconds"
      end
    end

    reader.close

    if result.is_a?(Hash) && result[:error]
      raise result[:error]
    end

    result
  rescue Errno::ECHILD, NotImplementedError
    # Fork not available, fall back to thread-based
    execute_with_thread_timeout(timeout_value, &block)
  end

  # Improved thread-based timeout
  def execute_with_thread_timeout(timeout_value, &block)
    result = nil
    exception = nil
    completed = false

    thread = Thread.new do
      begin
        result = yield
      rescue => e
        exception = e
      ensure
        completed = true
      end
    end

    # Wait for completion or timeout
    unless thread.join(timeout_value)
      thread.kill
      thread.join(0.1)  # Give thread time to clean up
      raise Timeout::Error, "execution expired after #{timeout_value} seconds"
    end

    raise exception if exception
    result
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
