require 'rubygems'

Gem::Specification.new do |spec|
  spec.name       = 'attempt'
  spec.version    = '0.2.1'
  spec.author     = 'Daniel J. Berger'
  spec.license    = 'Artistic 2.0'
  spec.email      = 'djberg96@gmail.com'
  spec.homepage   = 'http://github.com/djberg96/attempt'
  spec.summary    = 'A thin wrapper for begin + rescue + sleep + retry'
  spec.test_file  = 'test/test_attempt.rb'
  spec.files      = Dir['**/*'].reject{ |f| f.include?('git') }
  spec.cert_chain = Dir['certs/*']
  
  spec.extra_rdoc_files  = ['README','CHANGES','MANIFEST']

  spec.add_dependency('structured_warnings')
  spec.add_development_dependency('test-unit')

  spec.description = <<-EOF
    The attempt library provides a thin wrapper for the typical
    begin/rescue/sleep/retry dance. Use this in order to robustly
    handle blocks of code that could briefly flake out, such as a socket
    or database connection, where it's often better to try again after
    a brief period rather than fail immediately.
  EOF
end
