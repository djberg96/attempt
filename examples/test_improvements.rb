#!/usr/bin/env ruby

require_relative 'lib/attempt'

puts "=== Testing Improved Attempt Library ==="

# Test 1: Basic functionality
puts "\n1. Basic retry functionality:"
begin
  counter = 0
  result = attempt(tries: 3, interval: 0.1) do
    counter += 1
    puts "  Attempt #{counter}"
    raise "Simulated error" if counter < 3
    "Success!"
  end
  puts "  Result: #{result}"
rescue => e
  puts "  Final error: #{e.message}"
end

# Test 2: Parameter validation (our improvement)
puts "\n2. Parameter validation:"
begin
  Attempt.new(tries: -1)
rescue ArgumentError => e
  puts "  ✓ Caught invalid tries: #{e.message}"
end

begin
  Attempt.new(interval: -5)
rescue ArgumentError => e
  puts "  ✓ Caught invalid interval: #{e.message}"
end

# Test 3: Configuration inspection (our improvement)
puts "\n3. Configuration inspection:"
attempt_obj = Attempt.new(tries: 5, interval: 2, increment: 1)
puts "  Configuration: #{attempt_obj.configuration}"
puts "  Timeout enabled: #{attempt_obj.timeout_enabled?}"

# Test 4: Better error messaging (our improvement)
puts "\n4. Improved error logging:"
begin
  attempt(tries: 2, interval: 0.1, warnings: false) do
    raise StandardError, "This is a test error"
  end
rescue => e
  puts "  Final error class: #{e.class}"
  puts "  Final error message: #{e.message}"
end

# Test 5: Timeout with numeric value (our improvement)
puts "\n5. Numeric timeout:"
begin
  result = attempt(tries: 1, timeout: 0.1) do
    sleep 0.05 # This should succeed
    "Completed within timeout"
  end
  puts "  ✓ #{result}"
rescue Timeout::Error
  puts "  ✗ Timed out unexpectedly"
end

puts "\n=== All tests completed ==="
