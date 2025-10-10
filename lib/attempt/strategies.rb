# frozen_string_literal: true

require_relative 'timeout'

# Timeout strategy implementations for the Attempt library
module AttemptStrategies
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
    when :fiber
      execute_with_fiber_timeout(timeout_value, &block)
    when :ruby_timeout
      Timeout.timeout(timeout_value, &block)
    else  # :auto
      execute_with_auto_timeout(timeout_value, &block)
    end
  end

  # Automatic timeout strategy selection
  def execute_with_auto_timeout(timeout_value, &block)
    # Detect the optimal strategy based on the block
    strategy = detect_optimal_strategy(&block)

    case strategy
    when :fiber
      execute_with_fiber_timeout(timeout_value, &block)
    when :thread
      execute_with_thread_timeout(timeout_value, &block)
    when :process
      execute_with_process_timeout(timeout_value, &block)
    else
      execute_with_custom_timeout(timeout_value, &block)
    end
  rescue NameError, NoMethodError
    # Fall back to other strategies if preferred strategy fails
    execute_with_fallback_timeout(timeout_value, &block)
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
    if respond_to?(:system) && (!defined?(RUBY_ENGINE) || RUBY_ENGINE != 'jruby')
      return execute_with_process_timeout(timeout_value, &block)
    end

    # Strategy 3: Fiber-based timeout (lightweight alternative)
    begin
      return execute_with_fiber_timeout(timeout_value, &block)
    rescue NameError, NoMethodError
      # Fiber support may not be available in all Ruby versions
    end

    # Strategy 4: Thread-based timeout with better error handling
    return execute_with_thread_timeout(timeout_value, &block)
  rescue
    # Strategy 5: Last resort - use Ruby's Timeout (least reliable)
    Timeout.timeout(timeout_value, &block)
  end

  # Fiber-based timeout - lightweight alternative
  def execute_with_fiber_timeout(timeout_value, &block)
    begin
      return AttemptTimeout.fiber_timeout(timeout_value, &block)
    rescue AttemptTimeout::Error => e
      raise Timeout::Error, e.message  # Convert to expected exception type
    end
  end
end
