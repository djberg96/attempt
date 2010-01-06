require 'rubygems'

Gem::Specification.new do |gem|
   gem.name      = 'attempt'
   gem.version   = '0.2.0'
   gem.author    = 'Daniel J. Berger'
   gem.license   = 'Artistic 2.0'
   gem.email     = 'djberg96@gmail.com'
   gem.homepage  = 'http://www.rubyforge.org/projects/shards'
   gem.summary   = 'A thin wrapper for begin + rescue + sleep + retry'
   gem.test_file = 'test/test_attempt.rb'
   gem.has_rdoc  = true
   gem.files     = Dir['**/*'].reject{ |f| f.include?('CVS') }

   gem.extra_rdoc_files  = ['README','CHANGES','MANIFEST']
   gem.rubyforge_project = 'shards'

   gem.add_dependency('structured_warnings')
   gem.add_development_dependency('test-unit', '>= 2.0.3')

   gem.description = <<-EOF
      The attempt library provides a thin wrapper for the typical
      begin/rescue/sleep/retry dance. Use this in order to robustly
      handle blocks of code that could briefly flake out, such as a socket
      or database connection, where it's often better to try again after
      a brief period rather than fail immediately.
   EOF
end
