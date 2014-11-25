# coding: utf-8
class Fluent::HttpAltOutput < Fluent::BufferedOutput
  Fluent::Plugin.register_output('http_alt', self)

  config_param :endpoint_url, :string
  config_param :append_tag_to_endpoint_url, :bool, :default => false
  config_param :http_open_timeout, :integer, :default => 60
  config_param :http_read_timeout, :integer, :default => 60
  config_param :retry_http_statuses, :string, :default => "404,408,413,414,500,503" # inspired by ablagoev/fluent-plugin-out-http-buffered

  def initialize
    super
  end

  def configure(conf)
    super
    @retry_st = @retry_http_statuses.split(",").map(&:to_i)
  end

  def start
    super
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    [tag, time, record].to_msgpack # buffering format = msgpack
  end

  # TODO: Split method
  def write(chunk)
    require "net/http"
    in_chunk_cnt = 0
    chunk.msgpack_each do |tag, time, msg|
      uri = endpoint(tag)
      req = Net::HTTP.const_get(:post.to_s.capitalize).new(uri.path)
      req.content_type = "application/json"
      require "yajl"
      req.body = Yajl::Encoder.encode(msg)
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = @http_open_timeout
      http.read_timeout = @http_read_timeout
      chunk_id = decode_unique_id(chunk.unique_id)
      in_chunk_cnt += 1 # for Error display
      begin
        logger("Send to #{uri.to_s}, chunk_id:#{chunk_id}, in_chunk_cnt:#{in_chunk_cnt}")
        logger("Inspect>> #{req.body}", :debug)
        res = http.start{|c|c.request(req)}
        fail "Retry. Due to HTTP status was #{res.code}. chunk_id:#{chunk_id}, in_chunk_cnt:#{in_chunk_cnt}" if @retry_st.include?(res.code.to_i)
        logger("Send success, chunk_id:#{chunk_id}, in_chunk_cnt:#{in_chunk_cnt}")
      rescue => e
        logger(e, :warn)
        raise e
      ensure
        body = begin
                 (res.body.length > 100) ? res.body[0..99] + "\n--snipped--" : res.body
               rescue
                 nil # case of raise HTTP exception, `res` is nil.
               end
        logger("Inspect>> #{body}", :debug)
      end
    end
  end

  def endpoint(tag)
    # TBD: support sprintf format ??
    URI.parse(@append_tag_to_endpoint_url ? @endpoint_url+tag : @endpoint_url)
  end

  def logger(line, level = :info)
    log.send(level, "out_http_alt: #{line}")
  end

  def decode_unique_id(chunk_unique_id)
    x = chunk_unique_id.length / 2 - 1
    chunk_unique_id[0..x].unpack("C*").map{|i|i.to_s(16)}.join
  end
end

