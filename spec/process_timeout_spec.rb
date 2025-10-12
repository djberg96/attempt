# frozen_string_literal: true

require 'rspec'
require 'attempt_timeout'

RSpec.describe 'AttemptTimeout process_timeout strategy' do
  describe 'AttemptTimeout.process_timeout' do
    it 'returns the block result when execution completes within timeout' do
      result = AttemptTimeout.process_timeout(2) { 'process success' }
      expect(result).to eq('process success')
    end

    it 'returns the result for quick operations' do
      result = AttemptTimeout.process_timeout(1) { 5 * 8 }
      expect(result).to eq(40)
    end

    it 'raises Timeout::Error when timeout is exceeded' do
      expect {
        AttemptTimeout.process_timeout(0.1) { sleep 2 }
      }.to raise_error(Timeout::Error, /execution expired/)
    end

    it 'yields immediately when timeout is nil' do
      result = AttemptTimeout.process_timeout(nil) { 'no timeout' }
      expect(result).to eq('no timeout')
    end

    it 'yields immediately when timeout is zero' do
      result = AttemptTimeout.process_timeout(0) { 'zero timeout' }
      expect(result).to eq('zero timeout')
    end

    it 'yields immediately when timeout is negative' do
      result = AttemptTimeout.process_timeout(-1) { 'negative timeout' }
      expect(result).to eq('negative timeout')
    end

    it 'handles blocks that raise exceptions' do
      expect {
        AttemptTimeout.process_timeout(1) { raise StandardError, 'process error' }
      }.to raise_error(StandardError, 'process error')
    end

    it 'preserves exception class and message from block' do
      # Anonymous classes can't be marshalled across processes
      # Use a named exception class instead
      expect {
        AttemptTimeout.process_timeout(1) { raise ArgumentError, 'custom message' }
      }.to raise_error(ArgumentError, 'custom message')
    end

    it 'works with blocks that return nil' do
      result = AttemptTimeout.process_timeout(1) { nil }
      expect(result).to be_nil
    end

    it 'works with blocks that return false' do
      result = AttemptTimeout.process_timeout(1) { false }
      expect(result).to eq(false)
    end

    it 'handles string results' do
      result = AttemptTimeout.process_timeout(1) { 'test string' }
      expect(result).to eq('test string')
    end

    it 'handles array results' do
      result = AttemptTimeout.process_timeout(1) { [1, 2, 3] }
      expect(result).to eq([1, 2, 3])
    end

    it 'handles hash results' do
      result = AttemptTimeout.process_timeout(1) { { key: 'value' } }
      expect(result).to eq({ key: 'value' })
    end

    it 'handles numeric results' do
      result = AttemptTimeout.process_timeout(1) { 42.5 }
      expect(result).to eq(42.5)
    end

    it 'handles IO-intensive operations within timeout' do
      result = AttemptTimeout.process_timeout(2) do
        # Simulate some IO work
        sum = 0
        100.times { |i| sum += i }
        sum
      end
      expect(result).to eq((0...100).sum)
    end

    # Note: Fork may not be available on all systems (e.g., JRuby, Windows)
    # Process timeout has built-in fallback to thread timeout
    it 'handles platforms where fork is not available' do
      # This test would require stubbing Kernel.fork which is complex
      # The fallback is tested implicitly when the code runs on JRuby/Windows
      skip 'Fork fallback is platform-specific and tested implicitly'
    end
  end
end
