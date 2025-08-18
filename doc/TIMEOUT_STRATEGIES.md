# ## Overview

The Attempt library now includes multiple timeout strategies to provide more reliable timeout behavior for arbitrary blocks of code.imeout Strategies in Attempt Library

## Overview

The Attempt library now includes multiple timeout strategies to provide more relia## Performance Comparison

- **Process**: Highest reliability, highest overhead
- **Self-Pipe**: High reliability, moderate overhead (good balance)
- **Custom**: Good reliability, low overhead
- **Thread**: Good reliability, very low overhead
- **Fiber**: Good reliability, lowest overhead (for cooperative code)
- **Ruby Timeout**: Lowest reliability, lowest overhead

## Problems with Ruby's Standard Timeout

Ruby's built-in `Timeout` module has several well-known issues:

1. **Thread Safety**: Uses `Thread#raise` which can interrupt critical sections
2. **Resource Leaks**: Abrupt termination can leave resources in inconsistent states
3. **Unreliable**: May not work with blocking C extensions
4. **Memory Issues**: Can cause memory corruption in some cases

## Available Timeout Strategies

### 1. `:auto` (Default)
Automatically selects the best available strategy based on the environment.

```ruby
attempt(timeout: 5, timeout_strategy: :auto) { risky_operation }
```

### 2. `:custom`
Uses our custom `AttemptTimeout` implementation that's safer than Ruby's `Timeout`.

```ruby
attempt(timeout: 5, timeout_strategy: :custom) { risky_operation }
```

**Advantages:**
- Safer than Ruby's Timeout
- Uses `Thread#join` instead of `Thread#raise`
- More graceful thread termination

### 3. `:thread`
Improved thread-based timeout with better cleanup.

```ruby
attempt(timeout: 5, timeout_strategy: :thread) { risky_operation }
```

**Advantages:**
- Better error handling than standard timeout
- Proper thread cleanup
- Works in most environments

### 4. `:process`
Fork-based timeout (most reliable for I/O operations).

```ruby
attempt(timeout: 5, timeout_strategy: :process) { risky_operation }
```

**Advantages:**
- Most reliable for blocking I/O operations
- Complete isolation from main process
- Works with C extensions that don't respond to signals

**Limitations:**
- Not available on all platforms (Windows, some Ruby implementations)
- Higher overhead due to process creation
- Results must be serializable with Marshal

### 5. `:self_pipe`
Self-pipe trick timeout (signal-safe, no threads, fork-based).

```ruby
attempt(timeout: 5, timeout_strategy: :self_pipe) { risky_operation }
```

**Advantages:**
- Signal-safe - doesn't use Thread#raise
- No thread creation overhead
- Works well with blocking I/O and C extensions
- Lighter weight than full `:process` strategy
- Reliable timeout mechanism using IO.select

**Limitations:**
- Requires fork support (not available on Windows or JRuby)
- Results must be serializable with Marshal
- Slightly more overhead than pure thread/fiber approaches
- Falls back to thread strategy if fork unavailable

### 6. `:fiber`
Fiber-based timeout (lightweight, cooperative scheduling).

```ruby
attempt(timeout: 5, timeout_strategy: :fiber) { risky_operation }
```

**Advantages:**
- Very lightweight - no thread creation overhead
- Good for cooperative code that yields control
- Hybrid implementation works with most code

**Limitations:**
- Pure fiber approach only works with cooperative code
- Falls back to fiber+thread hybrid for blocking operations
- Newer feature, less battle-tested

### 7. `:ruby_timeout`
Uses Ruby's standard Timeout module (for compatibility).

```ruby
attempt(timeout: 5, timeout_strategy: :ruby_timeout) { risky_operation }
```

**Use only when:**
- You need exact compatibility with existing code
- Other strategies don't work in your environment

## Strategy Selection Guidelines

### For I/O Operations (Network, File I/O)
```ruby
# Best: Self-pipe (good balance of reliability and performance)
attempt(timeout: 30, timeout_strategy: :self_pipe) { Net::HTTP.get(uri) }

# Alternative: Process-based (most reliable but heavier)
attempt(timeout: 30, timeout_strategy: :process) { Net::HTTP.get(uri) }

# Fallback: Custom timeout
attempt(timeout: 30, timeout_strategy: :custom) { Net::HTTP.get(uri) }
```

### For CPU-Intensive Operations
```ruby
# Best: Self-pipe (signal-safe, reliable)
attempt(timeout: 10, timeout_strategy: :self_pipe) { expensive_calculation }

# Alternative: Thread-based, custom, or fiber
attempt(timeout: 10, timeout_strategy: :thread) { expensive_calculation }
attempt(timeout: 10, timeout_strategy: :fiber) { cooperative_calculation }
```

### For Lightweight Operations
```ruby
# Best: Fiber (lowest overhead)
attempt(timeout: 5, timeout_strategy: :fiber) { quick_operation }

# Alternative: Custom
attempt(timeout: 5, timeout_strategy: :custom) { quick_operation }
```

### For General Use
```ruby
# Let the library choose automatically
attempt(timeout: 5) { some_operation }
```

## Configuration Examples

```ruby
# Configure timeout strategy for an instance
attempt_obj = Attempt.new(
  tries: 3,
  timeout: 30,
  timeout_strategy: :process
)

# Use with specific strategy
attempt_obj.attempt { risky_network_call }

# Or use the kernel method
attempt(tries: 5, timeout: 10, timeout_strategy: :custom) do
  # Your code here
end
```

## Performance Comparison

- **Process**: Highest reliability, highest overhead
- **Custom**: Good reliability, low overhead
- **Thread**: Good reliability, very low overhead
- **Ruby Timeout**: Lowest reliability, lowest overhead

## Migration Guide

Existing code will continue to work unchanged:

```ruby
# This still works exactly as before
attempt(timeout: 5) { some_operation }
```

To use improved timeout strategies:

```ruby
# Add timeout_strategy parameter
attempt(timeout: 5, timeout_strategy: :process) { some_operation }

# Or use the lightweight fiber strategy
attempt(timeout: 5, timeout_strategy: :fiber) { cooperative_operation }
```

The `:auto` strategy provides the best balance of reliability and compatibility for most use cases.
