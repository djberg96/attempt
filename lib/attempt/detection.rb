# frozen_string_literal: true

# Strategy detection logic for automatic timeout strategy selection
module AttemptStrategies
  # Detect the optimal timeout strategy based on block characteristics
  def detect_optimal_strategy(&block)
    # Quick heuristics for strategy selection
    source = extract_block_source(&block) if block.source_location

    if source
      # I/O operations - process strategy is most reliable
      return :process if source =~ /Net::HTTP|Socket|File\.|IO\.|system|`|Process\./

      # Sleep operations - thread strategy is better than fiber for blocking sleep
      return :thread if source =~ /\bsleep\b/

      # Event-driven code - fiber strategy works well
      return :fiber if source =~ /EM\.|EventMachine|Async|\.async|Fiber\.yield/

      # CPU-intensive - thread strategy
      return :thread if source =~ /\d+\.times|while|loop|Array\.new\(\d+\)/
    end

    # Use fiber detection if available (but be conservative)
    if AttemptTimeout.respond_to?(:fiber_compatible_block?) &&
       AttemptTimeout.fiber_compatible_block?(&block)
      return :fiber
    end

    # Default: custom timeout (safest general-purpose option)
    :custom
  end

  # Extract source code from a block for analysis
  def extract_block_source(&block)
    return nil unless block.respond_to?(:source_location)

    file, line = block.source_location
    return nil unless file && line && File.exist?(file)

    lines = File.readlines(file)
    # Simple extraction - get a few lines around the block
    start_line = [line - 1, 0].max
    end_line = [line + 3, lines.length - 1].min
    lines[start_line..end_line].join
  rescue
    nil
  end
end