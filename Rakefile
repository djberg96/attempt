require 'rake'
require 'rake/testtask'

desc "Cleanup any .gem or .rbc files"
task :clean do
  Dir['*.gem'].each{ |f| File.delete(f) }
  Dir['**/*.rbc'].each{ |f| File.delete(f) } # Rubinius
end

namespace :gem do
  desc 'Build the attempt gem'
  task :create do
    spec = eval(IO.read('attempt.gemspec'))
    Gem::Builder.new(spec).build
  end

  desc "Install the attempt gem"
  task :install => [:create] do
    file = Dir["*.gem"].first
    sh "gem install #{file}"
  end
end

Rake::TestTask.new do |t|
  task :test => :clean
  t.warning = true
  t.verbose = true
end

task :default => :test
