#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/attempt'

puts "Testing Self-Pipe Timeout Strategy"
puts "=" * 40

# Test 1: Successful operation that completes quickly
puts "\nTest 1: Quick operation (should succeed)"
begin
  result = attempt(timeout: 5, timeout_strategy: :self_pipe) do
    puts "  Performing quick calculation..."
    sleep(1)
    42 * 42
  end
  puts "  Success! Result: #{result}"
rescue => e
  puts "  Error: #{e.message}"
end

# Test 2: Operation that times out
puts "\nTest 2: Slow operation (should timeout)"
begin
  result = attempt(timeout: 2, timeout_strategy: :self_pipe) do
    puts "  Starting slow operation..."
    sleep(5)  # This will timeout
    "This shouldn't be reached"
  end
  puts "  Unexpected success: #{result}"
rescue Timeout::Error => e
  puts "  Expected timeout: #{e.message}"
rescue => e
  puts "  Unexpected error: #{e.message}"
end

# Test 3: Operation with return values
puts "\nTest 3: Operation with complex return value"
begin
  result = attempt(timeout: 3, timeout_strategy: :self_pipe) do
    puts "  Creating complex data structure..."
    sleep(0.5)
    {
      timestamp: Time.now,
      data: [1, 2, 3, 4, 5],
      nested: { success: true, value: "test" }
    }
  end
  puts "  Success! Result keys: #{result.keys}"
rescue => e
  puts "  Error: #{e.message}"
end

# Test 4: Operation that raises an exception
puts "\nTest 4: Operation that raises exception"
begin
  result = attempt(timeout: 3, timeout_strategy: :self_pipe) do
    puts "  About to raise an exception..."
    sleep(0.5)
    raise StandardError, "Test exception from within block"
  end
  puts "  Unexpected success: #{result}"
rescue StandardError => e
  puts "  Expected exception: #{e.message}"
rescue => e
  puts "  Unexpected error: #{e.message}"
end

# Test 5: I/O operation (what self-pipe is good for)
puts "\nTest 5: File I/O operation"
begin
  result = attempt(timeout: 3, timeout_strategy: :self_pipe) do
    puts "  Reading file..."
    # Create a temporary file and read it
    content = "Hello, self-pipe timeout!"
    File.write('/tmp/test_self_pipe.txt', content)
    File.read('/tmp/test_self_pipe.txt')
  end
  puts "  Success! Read: '#{result}'"
  File.delete('/tmp/test_self_pipe.txt') if File.exist?('/tmp/test_self_pipe.txt')
rescue => e
  puts "  Error: #{e.message}"
end

# Test 6: Fallback behavior on unsupported platforms
puts "\nTest 6: Checking platform support"
attempt_obj = Attempt.new(timeout: 1, timeout_strategy: :self_pipe)
if attempt_obj.send(:fork_available?)
  puts "  Fork is available - self-pipe strategy will work natively"
else
  puts "  Fork not available - will fall back to thread strategy"
end

puts "\nAll tests completed!"
