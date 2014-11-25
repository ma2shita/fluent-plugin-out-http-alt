require "webrick"

class MockWebServer
  attr_reader :results
  attr_accessor :server

  def initialize(host, port)
    @host = host
    @port = port
    @results = []
    logger = WEBrick::Log.new("/dev/null", WEBrick::BasicLog::DEBUG)
    @sv = WEBrick::HTTPServer.new(:BindAddress => host, :Port => port, :Logger => logger, :AccessLog => [])
    mount_urls
  end

  def mount_urls
    @sv.mount_proc("/") do |req, res|
      res.status = 200
      res.body = "running"
    end

    @sv.mount_proc("/200") do |req, res|
      r = case req.content_type.downcase
          when 'application/json'
            JSON.parse(req.body)
          end
      res.status = 200
      res.body = ''
      @results << r
    end

    @sv.mount_proc("/200/test") do |req, res|
      r = JSON.parse(req.body)
      res.status = 200
      res.body = ''
      @results << r
    end

    @sv.mount_proc("/403") do |req, res|
      res.status = 403
      res.body = ""
    end

    @sv.mount_proc("/404") do |req, res|
      res.status = 404
      res.body = ""
    end

    @sv.mount_proc("/500") do |req, res|
      res.status = 500
      res.body = ""
    end

    @sv.mount_proc("/read_timeout") do |req, res|
      sleep 3
      res.status = 200
      res.body = ""
    end
  end

  def start
    @server = Thread.new {
      begin
        @sv.start
      ensure
        @sv.shutdown
      end
    }

    cv = ConditionVariable.new
    Thread.new {
      require "net/http"
      begin
        ::Net::HTTP.start(@host, @port){|http|http.get("/")}
      rescue
        retry
      end
      cv.signal
    }

    m = Mutex.new
    m.synchronize { cv.wait(m) }
    $stderr.puts "HTTP server boot."
  end

  def clear_results
    @results = []
  end
end

