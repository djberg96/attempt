#!/usr/bin/env ruby

require_relative 'lib/attempt'
require 'benchmark'

puts "=== Testing Different Timeout Strategies ==="

def blocking_operation(duration)
  start_time = Time.now
  while Time.now - start_time < duration
    # Simulate CPU-intensive work
    1000.times { Math.sqrt(rand) }
  end
  "Completed after #{duration}s"
end

def io_operation(duration)
  sleep duration
  "IO completed after #{duration}s"
end

strategies = [:auto, :custom, :thread, :process, :fiber, :ruby_timeout]

strategies.each do |strategy|
  puts "\n--- Testing #{strategy.to_s.upcase} strategy ---"

  # Test 1: Operation that completes within timeout
  begin
    result = attempt(tries: 1, timeout: 2, timeout_strategy: strategy) do
      io_operation(0.1)
    end
    puts "✓ Fast operation: #{result}"
  rescue => e
    puts "✗ Fast operation failed: #{e.message}"
  end

  # Test 2: Operation that times out
  begin
    time = Benchmark.realtime do
      attempt(tries: 1, timeout: 0.5, timeout_strategy: strategy) do
        io_operation(2)  # This should timeout
      end
    end
    puts "✗ Timeout test failed - should have timed out"
  rescue Timeout::Error => e
    puts "✓ Timeout worked: #{e.message}"
  rescue => e
    puts "✗ Unexpected error: #{e.class}: #{e.message}"
  end
end

# Test configuration inspection
puts "\n--- Configuration Test ---"
attempt_obj = Attempt.new(tries: 3, timeout: 5, timeout_strategy: :process)
puts "Configuration: #{attempt_obj.configuration}"

puts "\n=== All timeout strategy tests completed ==="
