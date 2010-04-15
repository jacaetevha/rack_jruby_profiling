require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

module TestHelpers
  def basic_application(code)
    Proc.new { |env| 
      500.times {|t| "construct a string for #{t} just so that we have some work to do in this application"}
      500.times {|t| [t, t/4.0].max }
      [code, {"Content-Type" => "text/plain", "Content-Length" => "3"}, [code.to_s]] 
    }
  end
  
  def error_application(error)
    Proc.new { |env| raise error }
  end
  
  def response_for(app, request)
    @profiler = Rack::JRubyProfiler.new(app)
    @profiler.call(request)
  end
  
  def all_profiles
    Dir["./#{@path}*"]
  end
  
  def first_profile
    all_profiles.first
  end
end

describe Rack::JRubyProfiler do
  include Rack::Test::Methods
  include TestHelpers
  
  before :each do
    @path = 'profile_test'
    @request = Rack::MockRequest.env_for("/#{@path}")
  end
  
  after :each do
    if @profiler && @profiler.profile_file
      File.delete @profiler.profile_file
    end
  end
  
  it "shouldn't profile is the no_profile query parameter is set" do
    @request = Rack::MockRequest.env_for("/profile_test?no_profile=true")
    response = response_for( basic_application(200), @request )
    response.should == basic_application(200).call(nil)
  end
  
  [200, 301, 404, 500].each do | code |
    it "should successfully respond with 200 if down-stream app returns #{code}" do
      response = response_for( basic_application(code), @request )
      response[0].should == 200
      response[1].should include("Content-Type")
      response[1]["Content-Type"].should == 'text/html'
      @profiler.profile_file.should_not be_nil
      response[2].class.should == String
      response[2].length.should > 0
      response[2].should == File.read(@profiler.profile_file)
    end
  end
  
  it "should NOT mask when a down-stream app throws an error" do
    request = Rack::MockRequest.env_for("/profile_test")
    lambda{ response_for( error_application('ka-boom!'), request ) }.should raise_error('ka-boom!')
  end

  class Tuple
    TRUISH = %w{true t yes y}
    attr_reader :profile_type, :content_type, :partial_filename, :extension
    
    def initialize(profile_type, content_type, partial_filename=nil)
      @profile_type = profile_type
      @content_type = content_type
      @partial_filename = (partial_filename || profile_type)
      @extension = content_type == :plain ? 'txt' : 'html'
    end
    
    def download
      TRUISH[rand(TRUISH.length)]
    end
  end
  
  [
    Tuple.new(:flat, :plain), 
    Tuple.new(:graph, :plain), 
    Tuple.new(:call_tree, :plain), 
    Tuple.new(:graph_html, :html, :graph), 
    Tuple.new(:tree_html, :html, :call_tree)
  ].each do |tuple|
    it "should construct a #{tuple.profile_type} profile with content type of #{tuple.content_type} and download it" do
      @request = Rack::MockRequest.env_for("/profile_test?profile=#{tuple.profile_type}&download=#{tuple.download}")
      response = response_for( basic_application(200), @request )
      response[0].should == 200
      response[1].should include("Content-Type")
      response[1]["Content-Type"].should == "text/#{tuple.content_type}"
      
      @profiler.profile_file.should_not be_nil
      @profiler.profile_file.should =~ /profile_test_#{tuple.partial_filename}_\d+\.#{tuple.extension}$/
      response[1].should include("Content-Disposition")
      response[1]["Content-Disposition"].should =~ Regexp.compile(%(attachment; filename="#{File.basename(@profiler.profile_file)}"))
      response[2].class.should == String
      response[2].should == File.read(@profiler.profile_file)
    end
  end
end
