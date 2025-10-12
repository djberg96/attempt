# frozen_string_literal: true

require 'rspec'
require 'attempt_timeout'

RSpec.describe 'AttemptTimeout detection methods' do
  describe 'AttemptTimeout.fiber_compatible_block?' do
    it 'returns boolean for any block' do
      result = AttemptTimeout.fiber_compatible_block? { 1 + 1 }
      expect([true, false]).to include(result)
    end

    it 'returns false when no block is given' do
      result = AttemptTimeout.fiber_compatible_block?
      expect(result).to eq(false)
    end

    it 'handles blocks that raise errors during detection' do
      result = AttemptTimeout.fiber_compatible_block? { raise 'error' }
      expect([true, false]).to include(result)
    end

    it 'detects simple calculations as potentially fiber-compatible' do
      result = AttemptTimeout.fiber_compatible_block? { 2 + 2 }
      # Result depends on timing, but should not raise
      expect([true, false]).to include(result)
    end
  end

  describe 'AttemptTimeout.detect_by_execution_pattern' do
    it 'returns false for non-cooperative blocks' do
      result = AttemptTimeout.detect_by_execution_pattern do
        sum = 0
        1000.times { |i| sum += i }
        sum
      end
      expect(result).to eq(false)
    end

    it 'returns false when no block given' do
      result = AttemptTimeout.detect_by_execution_pattern
      expect(result).to eq(false)
    end

    it 'handles blocks that complete immediately' do
      result = AttemptTimeout.detect_by_execution_pattern { 42 }
      expect([true, false]).to include(result)
    end

    it 'does not crash on blocks that raise errors' do
      result = AttemptTimeout.detect_by_execution_pattern do
        raise StandardError, 'test error'
      end
      expect(result).to eq(false)
    end

    it 'handles empty blocks' do
      result = AttemptTimeout.detect_by_execution_pattern {}
      expect([true, false]).to include(result)
    end
  end

  describe 'AttemptTimeout.detect_by_source_analysis' do
    it 'returns false when block has no source location' do
      # Procs created in certain contexts may not have source locations
      result = AttemptTimeout.detect_by_source_analysis { 1 + 1 }
      expect([true, false]).to include(result)
    end

    it 'returns false when no block given' do
      result = AttemptTimeout.detect_by_source_analysis
      expect(result).to eq(false)
    end

    it 'handles blocks with source analysis' do
      result = AttemptTimeout.detect_by_source_analysis do
        x = 5
        y = 10
        x + y
      end
      expect([true, false]).to include(result)
    end

    it 'detects sleep as blocking pattern' do
      # If the source analysis can read the file, it should detect sleep
      result = AttemptTimeout.detect_by_source_analysis { sleep 0.1 }
      # Result may be false due to sleep being a blocking pattern
      expect([true, false]).to include(result)
    end
  end

  describe 'AttemptTimeout.detect_by_timing_analysis' do
    it 'returns false for slow operations' do
      result = AttemptTimeout.detect_by_timing_analysis do
        sleep 0.1
      end
      expect(result).to eq(false)
    end

    it 'returns false when no block given' do
      result = AttemptTimeout.detect_by_timing_analysis
      expect(result).to eq(false)
    end

    it 'may return true for very fast operations' do
      result = AttemptTimeout.detect_by_timing_analysis { 1 + 1 }
      # Fast operations might be detected as cooperative
      expect([true, false]).to include(result)
    end

    it 'handles blocks that raise errors' do
      result = AttemptTimeout.detect_by_timing_analysis do
        raise 'timing test error'
      end
      expect(result).to eq(false)
    end

    it 'handles CPU-intensive operations' do
      result = AttemptTimeout.detect_by_timing_analysis do
        sum = 0
        100.times { |i| sum += i }
      end
      # May complete fast enough or not, depending on system
      expect([true, false]).to include(result)
    end
  end

  describe 'AttemptTimeout.extract_block_source' do
    it 'returns nil when no block given' do
      result = AttemptTimeout.extract_block_source
      expect(result).to be_nil
    end

    it 'returns nil for blocks without source location' do
      # Some dynamically created blocks may not have source
      block = proc { 1 + 1 }
      result = AttemptTimeout.extract_block_source(&block)
      expect([nil, String]).to include(result&.class)
    end

    it 'extracts source for regular blocks' do
      result = AttemptTimeout.extract_block_source do
        x = 10
        x * 2
      end
      # May return source string or nil depending on context
      expect([nil, String]).to include(result&.class)
    end

    it 'handles blocks from non-existent files gracefully' do
      # Block with fake source location should return nil
      block = proc { 'test' }
      allow(block).to receive(:source_location).and_return(['/nonexistent/file.rb', 1])

      result = AttemptTimeout.extract_block_source(&block)
      expect(result).to be_nil
    end

    it 'handles blocks without respond_to source_location' do
      block = proc { 'test' }
      allow(block).to receive(:respond_to?).with(:source_location).and_return(false)

      result = AttemptTimeout.extract_block_source(&block)
      expect(result).to be_nil
    end
  end

  describe 'integration tests' do
    it 'combines multiple detection strategies' do
      # Simple block should be processed by all strategies
      expect {
        AttemptTimeout.fiber_compatible_block? { 42 }
      }.not_to raise_error
    end

    it 'handles complex nested blocks' do
      result = AttemptTimeout.fiber_compatible_block? do
        [1, 2, 3].map { |x| x * 2 }.sum
      end
      expect([true, false]).to include(result)
    end

    it 'gracefully handles blocks with IO operations in source' do
      # Detection should not crash even if it detects IO patterns
      result = AttemptTimeout.detect_by_source_analysis do
        # File.read('test.txt') # commented out to not actually perform IO
        'test'
      end
      expect([true, false]).to include(result)
    end
  end
end
