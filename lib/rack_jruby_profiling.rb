require 'jruby-prof'

module Rack
  # Based on rack/contrib/profiling
  #
  # Set the profile=call_tree query parameter to view a calltree profile of the request.
  #
  # Set the download query parameter to download the result locally.
  #
  # Set the no_profile query parameter to selectively turn off profiling on certain requests.
  #
  # Both the no_profile and download parameters take a tru-ish value, one of [y, yes, t, true]
  #
  class JRubyProfiler
    DEFAULT_CONTENT_TYPE = 'text/html'

    PRINTER_CONTENT_TYPE = {
      :print_flat_text => 'text/plain',
      :print_graph_text => 'text/plain',
      :print_call_tree => 'text/plain',
      :print_graph_html => 'text/html',
      :print_tree_html => 'text/html'
    }
    
    DEFAULT_PRINTER = :print_tree_html

    PRINTER_METHODS = {
      :flat => :print_flat_text,
      :graph => :print_graph_text,
      :call_tree => :print_call_tree,
      :graph_html => :print_graph_html,
      :tree_html => :print_tree_html
    }
    
    FILE_NAMING = {
      :print_flat_text => 'flat',
      :print_graph_text => 'graph',
      :print_call_tree => 'call_tree',
      :print_graph_html => 'graph',
      :print_tree_html => 'call_tree'
    }

    # Accepts a :times => [Fixnum] option defaulting to 1.
    def initialize(app, options = {})
      @app = app
      @times = (options[:times] || 1).to_i
    end

    def call(env)
      profile(env)
    end
    
    def profile_file
      @profile_file
    end

    private
      def profile(env)
        request  = Rack::Request.new(env)
        @printer = parse_printer(request.params.delete('profile'))
        if JRubyProf.running? || boolean(request['no_profile'])
          @app.call(env)
        else
          begin
            count  = (request.params.delete('times') || @times).to_i
            result = JRubyProf.profile do
              count.times { @app.call(env) }
            end
            @uniq_id = Java::java.lang.System.nano_time
            @profile_file = ::File.expand_path( filename(@printer, env) )
            [200, headers(@printer, request, env), print(@printer, request, env, result)]
          ensure
            JRubyProf.stop
          end
        end
      end
      
      def filename(printer, env)
        extension = printer.to_s.include?("html") ? "html" : "txt"
        "#{::File.basename(env['PATH_INFO'])}_#{FILE_NAMING[printer]}_#{@uniq_id}.#{extension}"
      end

      def print(printer, request, env, result)
        return result if printer.nil?
        filename = filename(printer, env)
        JRubyProf.send(printer, result, filename)
        ::File.read filename
      end

      def headers(printer, request, env)
        headers = { 'Content-Type' => PRINTER_CONTENT_TYPE[printer] || DEFAULT_CONTENT_TYPE }
        if boolean(request.params['download'])
          filename = filename(printer, env)
          headers['Content-Disposition'] = %(attachment; filename="#{filename}")
        end
        headers
      end
      
      def boolean(parameter)
        return false if parameter.nil?
        return true if %w{t true y yes}.include?(parameter.downcase)
        false
      end

      def parse_printer(printer)
        printer = printer.to_sym rescue nil
        if printer.nil?
          DEFAULT_PRINTER
        else
          PRINTER_METHODS[printer] || DEFAULT_PRINTER
        end
      end
  end
end
