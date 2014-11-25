require "rubygems"
require "bundler"
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gem(s)"
  exit e.status_code
end

require "test/unit"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
$LOAD_PATH.unshift(File.dirname(__FILE__))

unless ENV.has_key?("VERBOSE")
  null_logger = Object.new
  null_logger.instance_eval do |obj|
    def method_missing(method, *args); end
  end
  $log = null_logger
end

require "pry-debugger"

HTTP_HOST = "localhost"
HTTP_PORT = 20145

require 'webrick'
require "fluent/test"
class HttpAltOutputTestBase < Test::Unit::TestCase
  def setup
    @results = []
    Fluent::Test.setup
    @dummy_server_thread = Thread.new do # inspired by ento/fluent-plugin-out-http
      srv = if ENV['VERBOSE']
              WEBrick::HTTPServer.new({:BindAddress => HTTP_HOST, :Port => HTTP_PORT})
            else
              logger = WEBrick::Log.new('/dev/null', WEBrick::BasicLog::DEBUG)
              WEBrick::HTTPServer.new({:BindAddress => HTTP_HOST, :Port => HTTP_PORT, :Logger => logger, :AccessLog => []})
            end
      begin
        # Target urls
        srv.mount_proc("/") do |req, res|
          res.status = 200
          res.body = "running"
        end

        srv.mount_proc("/200") do |req, res|
          r = case req.content_type.downcase
              when 'application/json'
                JSON.parse(req.body)
              end
          res.status = 200
          res.body = ''
          instance_variable_get(:@results).push(r)
        end

        srv.mount_proc("/200/test") do |req, res|
          r = JSON.parse(req.body)
          res.status = 200
          res.body = ''
          instance_variable_get(:@results).push(r)
        end

        srv.mount_proc("/403") do |req, res|
          res.status = 403
          res.body = ""
        end

        srv.mount_proc("/404") do |req, res|
          res.status = 404
          res.body = ""
        end

        srv.mount_proc("/500") do |req, res|
          res.status = 500
          res.body = ""
        end

        srv.mount_proc("/read_timeout") do |req, res|
          sleep 3
          res.status = 200
          res.body = ""
        end

        srv.start
      ensure
        srv.shutdown
      end
    end

    # to wait completion of dummy server.start()
    require 'thread'
    cv = ConditionVariable.new
    Thread.new {
      connected = false
      while not connected
        begin
          ::Net::HTTP.start(HTTP_HOST, HTTP_PORT) { |http| http.get("/") }
          connected = true
        rescue Errno::ECONNREFUSED
          sleep 0.1
        rescue StandardError => e
          p e
          sleep 0.1
        end
      end
      cv.signal
    } 
    mutex = Mutex.new
    mutex.synchronize {
      cv.wait(mutex)
    } 
  end

  def test_dummy_server
    client = Net::HTTP.start(HTTP_HOST, HTTP_PORT)
    assert_equal '200', client.request_get('/').code
  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end
end

require "fluent/plugin/out_http_alt"

