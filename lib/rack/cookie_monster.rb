module Rack
  class CookieMonster
    class Hungry < StandardError; end    
    
    class<<self      
      def configure
        @config ||= CookieMonsterConfig.new
        yield(@config)
        @configured = true
      end
    
      def paths
        ensure_monster_configured!
        @config.paths
      end
    
      def cookies
        ensure_monster_configured!
        @config.cookies
      end
      
      def configure_for_rails
        ensure_monster_configured!
        ActionController::Dispatcher.middleware.insert_before(
          ActionController::Base.session_store,
          self
        )
      end
      
      private      
        def ensure_monster_configured!
          raise Hungry.new("Cookie Monster has not been configured") unless @configured
        end
    end
    
    def initialize(app, opts=nil)
      @app    = app
      @config = opts.nil? ? self.class : CookieMonsterConfig.new(opts)
    end
  
    def call(env)
      shares_with(env["REQUEST_URI"]) do
        request = ::Rack::Request.new(env)
        eat_cookies!(env, request)
      end
      @app.call(env)
    end

    private  
      def shares_with(path)
        yield if @config.paths.empty?
    
        any_matches = @config.paths.any? do |snacker|
          case snacker
          when String
            snacker == path
          when Regexp
            snacker.match(path) != nil
          end
        end
    
        yield if any_matches
      end
  
      def eat_cookies!(env, request)
        cookies = request.cookies
        new_cookies = {}
      
        @config.cookies.each do |cookie_name| 
          value = request.params[cookie_name.to_s]
          if value
            cookies.delete(cookie_name.to_s)
            new_cookies[cookie_name.to_s] = value
          end
        end
      
        new_cookies.merge!(cookies)    
        env["HTTP_COOKIE"] = new_cookies.map do |k,v|
          "#{k}=#{v}"
        end.compact.join("; ").freeze
      end
  end
  
  class CookieMonsterConfig
    attr_reader :cookies, :paths

    def initialize
      @cookies = []
      @paths   = []
    end

    def share(cookie)
      @cookies << cookie.to_sym
    end

    def for_path(path)
      @paths << path
    end
  end
end