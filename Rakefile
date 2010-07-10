require "rubygems"
require "spec/rake/spectask"
# begin
#   require "vlad"
#   Vlad.load(:scm => :git, :app => nil, :web => nil)
# rescue LoadError
# end

desc "Run all specs in spec directory"
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_files = FileList["spec/*_spec.rb"]
end

task :default => :spec