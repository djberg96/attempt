[![Ruby](https://github.com/djberg96/attempt/actions/workflows/ruby.yml/badge.svg)](https://github.com/djberg96/attempt/actions/workflows/ruby.yml)

## Description
A thin wrapper for begin + rescue + sleep + retry.

## Installation
`gem install attempt`

## Adding the trusted cert
`gem cert --add <(curl -Ls https://raw.githubusercontent.com/djberg96/attempt/main/certs/djberg96_pub.pem)`

## Synopsis
```ruby
require 'attempt'
 
# Attempt to ftp to some host, trying 3 times with 30 seconds between
# attempts before finally raising an error.

attempt(tries: 3, interval: 30){
  Net::FTP.open(host, user, passwd){ ... }
}
 
# Or, do things the long way...
code = Attempt.new do |a|
  a.tries    = 3
  a.interval = 30
end
 
code.attempt{
  Net::FTP.open(host, user, passwd){ ... }
}
```

## Known Bugs
None that I'm aware of. If you find any bugs, please log them on the project page at:

https://github.com/djberg96/attempt

## Caveats
Use with caution. Specifically, make sure you aren't inadvertantly
wrapping code that already performs sleep + retry. Otherwise, you'll
end up with a series of nested retry's that could take much longer to
work than you expect. 

Also, this library uses the timeout library internally, which has some
known issues. See Future Plans, below.

As of version 0.3.0, this library requires structured_warnings 0.3.0 or
later. This is necessary because of changes in Ruby 2.4.

Update: I've switched from the timeout library in the standard library to
the safe_timeout library on non-Windows platforms which should improve things.
In addition, the structured_warnings library requirement is now 0.4.0 or later
in order to work with Ruby 2.7.

## Future Plans
Add the ability to set an absolute maximum number of seconds to prevent
nested sleep/retry from delaying attempts longer than expected.

Replace the timeout library with a self selecting pipe if possible.

## Acknowledgements
This library is partially based on Mark Fowler's 'Attempt' Perl module.

## See Also
If you're looking for a heavier but more robust solution designed for remote
services, please take a look at gems like "circuitbox" or "faulty".

## Warranty
This package is provided "as is" and without any express or
implied warranties, including, without limitation, the implied
warranties of merchantability and fitness for a particular purpose.

## License
Apache-2.0

## Copyright
(C) 2006-2025, Daniel J. Berger
All Rights Reserved

## Author
Daniel J. Berger
