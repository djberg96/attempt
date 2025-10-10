# frozen_string_literal: true

# Thread-based timeout strategy implementation
module AttemptStrategies
  # Improved thread-based timeout
  def execute_with_thread_timeout(timeout_value, &block)
    result = nil
    exception = nil
    completed = false

    thread = Thread.new do
      begin
        result = yield
      rescue => e
        exception = e
      ensure
        completed = true
      end
    end

    # Wait for completion or timeout
    unless thread.join(timeout_value)
      thread.kill
      thread.join(0.1)  # Give thread time to clean up
      raise Timeout::Error, "execution expired after #{timeout_value} seconds"
    end

    raise exception if exception
    result
  end
end
