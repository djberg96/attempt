require 'rake'
require 'rake/testtask'

desc "Install the attempt library (non-gem)"
task :install do
   cp 'lib/attempt.rb', Config::CONFIG['sitelibdir'], :verbose => true
end

desc 'Build the gem'
task :gem do
   spec = eval(IO.read('attempt.gemspec'))
   Gem::Builder.new(spec).buildend

desc "Install the attempt library as a gem"
task :install_gem => [:gem] do
   file = Dir["*.gem"].first
   sh "gem install #{file}"
end

Rake::TestTask.new do |t|
   t.warning = true
   t.verbose = true
end
