# frozen_string_literal: true

require 'spec_helper'
require 'attempt_timeout'

RSpec.describe 'AttemptTimeout thread_timeout strategy' do
  describe 'AttemptTimeout.thread_timeout' do
    it 'returns the block result when execution completes within timeout' do
      result = AttemptTimeout.thread_timeout(1) { 'success' }
      expect(result).to eq('success')
    end

    it 'returns the block result for quick operations' do
      result = AttemptTimeout.thread_timeout(1) { 2 + 2 }
      expect(result).to eq(4)
    end

    it 'raises Timeout::Error when timeout is exceeded' do
      expect {
        AttemptTimeout.thread_timeout(0.1) { sleep 2 }
      }.to raise_error(Timeout::Error, /execution expired after 0.1 seconds/)
    end

    it 'handles blocks that raise exceptions' do
      expect {
        AttemptTimeout.thread_timeout(1) { raise StandardError, 'block error' }
      }.to raise_error(StandardError, 'block error')
    end

    it 'yields immediately when timeout is nil' do
      result = AttemptTimeout.thread_timeout(nil) { 'no timeout' }
      expect(result).to eq('no timeout')
    end

    it 'yields immediately when timeout is zero' do
      result = AttemptTimeout.thread_timeout(0) { 'zero timeout' }
      expect(result).to eq('zero timeout')
    end

    it 'yields immediately when timeout is negative' do
      result = AttemptTimeout.thread_timeout(-1) { 'negative timeout' }
      expect(result).to eq('negative timeout')
    end

    it 'handles multiple sequential timeouts' do
      3.times do |i|
        result = AttemptTimeout.thread_timeout(1) { i * 2 }
        expect(result).to eq(i * 2)
      end
    end

    it 'cleans up thread resources after timeout' do
      initial_thread_count = Thread.list.size

      expect {
        AttemptTimeout.thread_timeout(0.1) { sleep 2 }
      }.to raise_error(Timeout::Error)

      sleep 0.2 # Give threads time to clean up
      expect(Thread.list.size).to be <= initial_thread_count + 1
    end

    it 'preserves exception class and message from block' do
      custom_error = Class.new(StandardError)

      expect {
        AttemptTimeout.thread_timeout(1) { raise custom_error, 'custom message' }
      }.to raise_error(custom_error, 'custom message')
    end

    it 'works with blocks that return nil' do
      result = AttemptTimeout.thread_timeout(1) { nil }
      expect(result).to be_nil
    end

    it 'works with blocks that return false' do
      result = AttemptTimeout.thread_timeout(1) { false }
      expect(result).to eq(false)
    end

    it 'handles nested thread timeout calls' do
      result = AttemptTimeout.thread_timeout(2) do
        AttemptTimeout.thread_timeout(1) { 'nested' }
      end
      expect(result).to eq('nested')
    end

    it 'times out outer call when inner completes but outer exceeds limit' do
      expect {
        AttemptTimeout.thread_timeout(0.1) do
          AttemptTimeout.thread_timeout(2) { sleep 0.5 }
        end
      }.to raise_error(Timeout::Error)
    end
  end
end
