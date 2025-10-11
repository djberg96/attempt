#!/usr/bin/env ruby

require_relative 'lib/attempt'

puts "=== Testing Fiber Timeout Strategy ==="

# Test 1: Basic fiber timeout functionality
puts "\n1. Testing fiber timeout with fast operation:"
begin
  result = attempt(tries: 1, timeout: 2, timeout_strategy: :fiber) do
    sleep 0.1
    "Fiber timeout test completed!"
  end
  puts "✓ #{result}"
rescue => err
  puts "✗ Error: #{err.message}"
end

# Test 2: Fiber timeout that should timeout
puts "\n2. Testing fiber timeout that should timeout:"
begin
  start_time = Time.now
  attempt(tries: 1, timeout: 0.5, timeout_strategy: :fiber) do
    sleep 2 # This should timeout
    "Should not reach here"
  end
  puts "✗ Should have timed out"
rescue Timeout::Error => err
  elapsed = Time.now - start_time
  puts "✓ Timed out as expected: #{err.message} (elapsed: #{elapsed.round(2)}s)"
rescue => err
  puts "✗ Unexpected error: #{err.class}: #{err.message}"
end

# Test 3: Compare fiber vs thread timeout performance
puts "\n3. Performance comparison:"
require 'benchmark'

operations = 10

puts "Fiber strategy:"
fiber_time = Benchmark.realtime do
  operations.times do
    attempt(tries: 1, timeout: 1, timeout_strategy: :fiber) do
      sleep 0.01
      "done"
    end
  end
end
puts "  #{operations} operations: #{fiber_time.round(4)}s"

puts "Thread strategy:"
thread_time = Benchmark.realtime do
  operations.times do
    attempt(tries: 1, timeout: 1, timeout_strategy: :thread) do
      sleep 0.01
      "done"
    end
  end
end
puts "  #{operations} operations: #{thread_time.round(4)}s"

puts "Custom strategy:"
custom_time = Benchmark.realtime do
  operations.times do
    attempt(tries: 1, timeout: 1, timeout_strategy: :custom) do
      sleep 0.01
      "done"
    end
  end
end
puts "  #{operations} operations: #{custom_time.round(4)}s"

# Test 4: Configuration inspection
puts "\n4. Configuration with fiber strategy:"
attempt_obj = Attempt.new(tries: 3, timeout: 5, timeout_strategy: :fiber)
config = attempt_obj.configuration
puts "Configuration: #{config}"

# Test 5: Error handling in fiber timeout
puts "\n5. Error handling in fiber timeout:"
begin
  attempt(tries: 1, timeout: 2, timeout_strategy: :fiber) do
    raise StandardError, "Test error in fiber"
  end
rescue StandardError => err
  puts "✓ Error properly caught: #{err.message}"
rescue => err
  puts "✗ Unexpected error type: #{err.class}: #{err.message}"
end

puts "\n=== Fiber timeout strategy tests completed ==="
