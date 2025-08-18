#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/attempt'

puts "Simple self-pipe test"

begin
  result = attempt(timeout: 5, timeout_strategy: :thread) do
    puts "Testing thread strategy first..."
    sleep(1)
    "success"
  end
  puts "Thread strategy result: #{result}"
rescue => e
  puts "Thread strategy error: #{e.message}"
end

begin
  result = attempt(timeout: 5, timeout_strategy: :self_pipe) do
    puts "Testing self-pipe strategy..."
    sleep(1)
    "success"
  end
  puts "Self-pipe strategy result: #{result}"
rescue => e
  puts "Self-pipe strategy error: #{e.message}"
  puts "Error class: #{e.class}"
  puts "Backtrace: #{e.backtrace.first(5).join("\n")}"
end

puts "Test completed"
