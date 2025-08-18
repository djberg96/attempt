#!/usr/bin/env ruby

require_relative '../lib/attempt'

puts "Testing fork availability..."
attempt_obj = Attempt.new(timeout: 1, timeout_strategy: :self_pipe)
puts "Fork available: #{attempt_obj.send(:fork_available?)}"

if attempt_obj.send(:fork_available?)
  puts "Testing self-pipe directly..."
  begin
    result = attempt_obj.send(:execute_with_self_pipe_timeout, 2) do
      puts "In child process"
      "test result"
    end
    puts "Result: #{result}"
  rescue => e
    puts "Error: #{e.message}"
    puts "Backtrace:"
    e.backtrace.first(10).each { |line| puts "  #{line}" }
  end
else
  puts "Fork not available, testing fallback..."
  begin
    result = attempt(timeout: 2, timeout_strategy: :self_pipe) do
      "fallback result"
    end
    puts "Fallback result: #{result}"
  rescue => e
    puts "Fallback error: #{e.message}"
  end
end

puts "Test complete"
