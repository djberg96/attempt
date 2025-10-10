# frozen_string_literal: true

# Process-based timeout strategy implementation
module AttemptStrategies
  # Process-based timeout - most reliable for I/O operations
  def execute_with_process_timeout(timeout_value, &block)
    reader, writer = IO.pipe

    pid = fork do
      reader.close
      begin
        result = yield
        Marshal.dump(result, writer)
      rescue => e
        Marshal.dump({error: e}, writer)
      ensure
        writer.close
      end
    end

    writer.close

    if Process.waitpid(pid, Process::WNOHANG)
      # Process completed immediately
      result = Marshal.load(reader)
    else
      # Wait for timeout
      if IO.select([reader], nil, nil, timeout_value)
        Process.waitpid(pid)
        result = Marshal.load(reader)
      else
        Process.kill('TERM', pid)
        Process.waitpid(pid)
        raise Timeout::Error, "execution expired after #{timeout_value} seconds"
      end
    end

    reader.close

    if result.is_a?(Hash) && result[:error]
      raise result[:error]
    end

    result
  rescue Errno::ECHILD, NotImplementedError
    # Fork not available, fall back to thread-based
    execute_with_thread_timeout(timeout_value, &block)
  end
end