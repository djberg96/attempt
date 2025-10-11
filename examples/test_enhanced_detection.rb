#!/usr/bin/env ruby

require_relative 'lib/attempt'

puts '=== Testing Enhanced Fiber Detection ==='

# Test cases to verify the enhanced detection
test_cases = [
  {
    name: 'CPU intensive operation (should use thread)',
    block: -> { 10_000.times { |i| i * 2 } },
    expected_strategy: :thread
  },
  {
    name: 'Sleep operation (should use thread - blocking)',
    block: -> { sleep(0.001) },
    expected_strategy: :thread # Changed from :fiber - sleep is blocking in fiber context
  },
  {
    name: 'File I/O operation (should use process)',
    block: -> { File.read(__FILE__) },
    expected_strategy: :process
  },
  {
    name: 'Network operation (should use process)',
    block: -> { Net::HTTP.get(URI('http://httpbin.org/json')) },
    expected_strategy: :process
  },
  {
    name: 'Simple calculation (should use custom/fiber)',
    block: -> { Math.sqrt(100) },
    expected_strategy: [:custom, :fiber] # Could be either
  }
]

puts "\n--- Strategy Detection Tests ---"

test_cases.each do |test_case|
  begin
    # Create an attempt instance to test strategy detection
    attempt_obj = Attempt.new(timeout: 1)

    # Access the private method for testing
    detected_strategy = attempt_obj.send(:detect_optimal_strategy, &test_case[:block])

    expected = test_case[:expected_strategy]
    passed = if expected.is_a?(Array)
      expected.include?(detected_strategy)
    else
      detected_strategy == expected
    end

    status = passed ? '✓ PASS' : '✗ FAIL'
    puts "#{test_case[:name]}: #{status}"
    puts "  Expected: #{expected}, Detected: #{detected_strategy}"

    # Also test fiber compatibility detection
    fiber_compatible = AttemptTimeout.fiber_compatible_block?(&test_case[:block])
    puts "  Fiber compatible: #{fiber_compatible}"

  rescue => err
    puts "#{test_case[:name]}: ✗ ERROR - #{err.message}"
  end
  puts
end

puts '--- Live Strategy Selection Test ---'

# Test actual timeout strategy selection in action
strategies_to_test = [
  {
    name: 'Auto-selected strategy for sleep',
    block: -> { sleep(0.01); 'sleep completed' },
    timeout: 1
  },
  {
    name: 'Auto-selected strategy for calculation',
    block: -> { 1000.times { |i| Math.sqrt(i) }; 'calculation completed' },
    timeout: 2
  }
]

strategies_to_test.each do |test|
  puts "\n#{test[:name]}:"
  begin
    start_time = Time.now

    result = attempt(tries: 1, timeout: test[:timeout]) do
      test[:block].call
    end

    elapsed = Time.now - start_time
    puts "  ✓ #{result} (#{elapsed.round(3)}s)"

  rescue => err
    puts "  ✗ #{err.class}: #{err.message}"
  end
end

puts "\n--- Fiber Detection Components Test ---"

# Test individual detection methods
test_block = -> { sleep(0.001) }

puts 'Testing detection methods for sleep operation:'
puts "  Execution pattern: #{AttemptTimeout.detect_by_execution_pattern(&test_block)}"
puts "  Source analysis: #{AttemptTimeout.detect_by_source_analysis(&test_block)}"
puts "  Timing analysis: #{AttemptTimeout.detect_by_timing_analysis(&test_block)}"
puts "  Overall compatible: #{AttemptTimeout.fiber_compatible_block?(&test_block)}"

puts "\n=== Enhanced detection tests completed ==="
