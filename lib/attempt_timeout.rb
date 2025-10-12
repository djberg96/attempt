require 'timeout'

# Custom timeout implementation that's more reliable than Ruby's Timeout module
class AttemptTimeout
  class Error < StandardError; end

  # More reliable timeout using Thread + sleep instead of Timeout.timeout
  # This approach is safer as it doesn't use Thread#raise
  def self.timeout(seconds)
    return yield if seconds.nil? || seconds <= 0

    result = nil
    exception = nil

    thread = Thread.new do
      begin
        result = yield
      rescue => err
        exception = err
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

  # Alternative: Fiber-based timeout (lightweight, cooperative)
  # Note: This only works for code that yields control back to the main thread
  def self.fiber_timeout(seconds, &block)
    return yield if seconds.nil? || seconds <= 0

    # For blocks that don't naturally yield, we need a different approach
    # We'll use a hybrid fiber + thread approach for better compatibility
    if fiber_compatible_block?(&block)
      fiber_only_timeout(seconds, &block)
    else
      fiber_thread_hybrid_timeout(seconds, &block)
    end
  end

  # Pure fiber-based timeout for cooperative code
  def self.fiber_only_timeout(seconds, &block)
    fiber = Fiber.new(&block)
    start_time = Time.now

    loop do
      elapsed = Time.now - start_time
      raise Error, "execution expired after #{seconds} seconds" if elapsed > seconds

      begin
        result = fiber.resume
        return result unless fiber.alive?
      rescue FiberError
        # Fiber is dead, which means it completed
        break
      end

      # Small sleep to prevent busy waiting and allow other operations
      sleep 0.001
    end
  end

  # Hybrid approach: fiber in a thread with timeout
  def self.fiber_thread_hybrid_timeout(seconds)
    result = nil
    exception = nil

    thread = Thread.new do
      fiber = Fiber.new do
        begin
          result = yield
        rescue => err
          exception = err
        end
      end

      # Resume the fiber until completion
      while fiber.alive?
        fiber.resume
        Thread.pass # Allow other threads to run
      end
    end

    if thread.join(seconds)
      raise exception if exception
      result
    else
      thread.kill
      thread.join(0.1)
      raise Error, "execution expired after #{seconds} seconds"
    end
  end

  # Simple heuristic to determine if a block is likely to be fiber-compatible
  # (This is a basic implementation - in practice, this is hard to determine)
  def self.fiber_compatible_block?(&block)
    # Try multiple detection strategies
    detect_by_execution_pattern(&block) ||
      detect_by_source_analysis(&block) ||
      detect_by_timing_analysis(&block)
  end

  # Method 1: Execute in a test fiber and see if it yields naturally
  def self.detect_by_execution_pattern(&block)
    return false unless block_given?

    test_fiber = Fiber.new(&block)
    start_time = Time.now
    yields_detected = 0

    # Try to resume the fiber multiple times with short intervals
    3.times do
      break unless test_fiber.alive?

      begin
        test_fiber.resume
        yields_detected += 1 if (Time.now - start_time) < 0.01 # Quick yield
      rescue FiberError
        break
      end
    end

    yields_detected > 1 # Multiple quick yields suggest cooperative behavior
  rescue
    false # If anything goes wrong, assume non-cooperative
  end

  # Method 2: Analyze the block's source code for yield indicators
  def self.detect_by_source_analysis(&block)
    return false unless block_given?

    source = extract_block_source(&block)
    return false unless source

    # Look for patterns that suggest yielding behavior
    yielding_patterns = [
      /\bFiber\.yield\b/,             # Explicit fiber yields
      /\bEM\.|EventMachine/,          # EventMachine operations
      /\bAsync\b/,                    # Async gem operations
      /\.async\b/,                    # Async method calls
      /\bawait\b/,                    # Await-style calls
      /\bIO\.select\b/,               # IO operations
      /\bsocket\./i                   # Socket operations
    ]

    blocking_patterns = [
      /\bsleep\b/,                    # sleep() calls - actually blocking in fiber context!
      /\bNet::HTTP\b/,                # HTTP operations - can block
      /\bwhile\s+true\b/,             # Infinite loops
      /\bloop\s+do\b/,                # Loop blocks
      /\d+\.times\s+do\b/,            # Numeric iteration
      /\bArray\.new\(/                # Large array creation
    ]

    has_yielding = yielding_patterns.any? { |pattern| source =~ pattern }
    has_blocking = blocking_patterns.any? { |pattern| source =~ pattern }

    has_yielding && !has_blocking
  rescue
    false
  end

  # Method 3: Time-based analysis - quick execution suggests yielding
  def self.detect_by_timing_analysis
    return false unless block_given?

    # Test execution in a thread with very short timeout
    start_time = Time.now
    completed = false

    test_thread = Thread.new do
      begin
        yield
        completed = true
      rescue
        # Ignore errors for detection purposes
      end
    end

    # If it completes very quickly or yields within 10ms, likely cooperative
    test_thread.join(0.01)
    execution_time = Time.now - start_time

    test_thread.kill unless test_thread.status.nil?
    test_thread.join(0.01)

    # Quick completion suggests either very fast operation or yielding behavior
    completed && execution_time < 0.005
  rescue
    false
  end

  # Extract source code from a block (Ruby 2.7+ method)
  def self.extract_block_source(&block)
    return nil unless block.respond_to?(:source_location)

    file, line = block.source_location
    return nil unless file && line && File.exist?(file)

    lines = File.readlines(file)
    # Simple extraction - in practice, you'd want more sophisticated parsing
    lines[(line - 1)..(line + 5)].join
  rescue
    nil
  end
end
