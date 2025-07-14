# Fiber Timeout Strategy Addition

## Summary

Added a new `:fiber` timeout strategy option to the Attempt library that provides a lightweight alternative to thread-based timeouts using Ruby's Fiber cooperative scheduling.

## Implementation Details

### New Method: `execute_with_fiber_timeout`
- Uses `AttemptTimeout.fiber_timeout` method
- Converts `AttemptTimeout::Error` to `Timeout::Error` for consistency
- Integrates seamlessly with existing timeout strategy infrastructure

### Enhanced `AttemptTimeout.fiber_timeout`
- **Hybrid Approach**: Automatically detects if code is fiber-cooperative
- **Pure Fiber Mode**: For truly cooperative code that yields control
- **Fiber+Thread Hybrid**: For blocking operations that need fiber benefits
- **Graceful Fallback**: Falls back to thread-based approach when needed

## Key Advantages

1. **Lowest Overhead**: No thread creation overhead for cooperative code
2. **Cooperative Scheduling**: Works well with fiber-based applications
3. **Hybrid Compatibility**: Works with both cooperative and blocking code
4. **Memory Efficient**: Lower memory footprint than thread-based timeouts
5. **Seamless Integration**: Drop-in replacement for other timeout strategies

## Usage Examples

```ruby
# Basic fiber timeout
attempt(timeout: 5, timeout_strategy: :fiber) { operation }

# Configuration with fiber strategy
attempt_obj = Attempt.new(
  tries: 3,
  timeout: 10,
  timeout_strategy: :fiber
)

# Performance-conscious applications
attempt(timeout: 1, timeout_strategy: :fiber) { lightweight_operation }
```

## Performance Characteristics

- **Best For**: Lightweight operations, cooperative code, high-frequency timeouts
- **Memory**: Lowest memory usage among all strategies
- **CPU**: Minimal CPU overhead for cooperative operations
- **Compatibility**: Works in all Ruby environments that support Fibers

## Integration Points

1. **Strategy Selection**: Added `:fiber` to timeout strategy options
2. **Auto Fallback**: Included in automatic strategy selection chain
3. **Documentation**: Updated all documentation to include fiber strategy
4. **Testing**: Comprehensive test suite validates fiber timeout behavior

## Backward Compatibility

- Fully backward compatible - existing code continues to work unchanged
- Opt-in feature - only used when explicitly specified
- Consistent error handling and API surface

The fiber timeout strategy provides developers with a high-performance, low-overhead option for timeout handling, especially valuable in fiber-based applications and scenarios requiring many concurrent timeout operations.
