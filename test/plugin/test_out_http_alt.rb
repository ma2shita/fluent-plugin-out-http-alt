# coding: utf-8
require "helper"

HTTP_HOST = "localhost"
HTTP_PORT = 20145
require "fluent/test/webserver"
$server = MockWebServer.new(HTTP_HOST, HTTP_PORT)
$server.start

class HttpAltOutputTest < Test::Unit::TestCase
  DEFAULT_CONF = %[
                  endpoint_url http://#{HTTP_HOST}:#{HTTP_PORT}/200
                  ]
  FIXED_TIME = Time.parse("2014-11-25 10:00:01").to_i
  FIXED_TAG = "test"

  def setup
    Fluent::Test.setup
    $server.clear_results
  end

  def create_driver(conf = DEFAULT_CONF, tag = FIXED_TAG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::HttpAltOutput, tag).configure(conf)
  end

  def test_config_append_tag_to_url
    require "uri"
    d = create_driver(%[
                      endpoint_url http://foo.bar/path?p=
                      ])
    assert_equal URI.parse("http://foo.bar/path?p="), d.instance.endpoint("this.is.test")
    d = create_driver(%[
                      endpoint_url http://foo.bar/path?p=
                      append_tag_to_endpoint_url true
                      ])
    assert_equal URI.parse("http://foo.bar/path?p=this.is.test"), d.instance.endpoint("this.is.test")
  end

  def test_emit
    d = create_driver
    d.emit([1, 2], FIXED_TIME)
    d.run
    assert_equal 1, $server.results.length
    assert_equal [1, 2], $server.results[0]
    logs = d.instance.log.logs
    assert_equal logs.length, 4
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send to #{d.instance.endpoint(FIXED_TAG)}, /).count, 1
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send success, /).count, 1
    assert_equal logs.grep(/ \[debug\]: out_http_alt: /).count, 2
  end

  def test_emit_jp_include
    d = create_driver
    d.emit([1, "日本語"], FIXED_TIME)
    d.run
    assert_equal 1, $server.results.length
    assert_equal [1, "日本語"], $server.results[0]
  end

  def test_emit_with_tag
    d = create_driver(%[
                        endpoint_url http://#{HTTP_HOST}:#{HTTP_PORT}/200/
                        append_tag_to_endpoint_url true
                      ])
    d.emit([1, 2], FIXED_TIME)
    d.run
    assert_equal 1, $server.results.length
    assert_equal [1, 2], $server.results[0]
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send to #{d.instance.endpoint(FIXED_TAG)}, /).count, 1
  end

  def test_multiple_buffering_single_emit
    d = create_driver
    d.emit([1, 2], FIXED_TIME)
    d.run
    d.run
    assert_equal 2, $server.results.length
    assert_equal [1, 2], $server.results[0]
    assert_equal [1, 2], $server.results[1]
    logs = d.instance.log.logs
    assert_equal logs.length, 8
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send to #{d.instance.endpoint(FIXED_TAG)}, /).count, 2
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send success, /).count, 2
    assert_equal logs.grep(/ \[debug\]: out_http_alt: /).count, 4
  end

  def test_raise_error_cannot_server_connect
    d = create_driver(%[endpoint_url http://#{HTTP_HOST}:1/])
    d.emit([1, 2], FIXED_TIME)
    assert_raise(Errno::ECONNREFUSED) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Connection refused/).count, 1
  end

  def test_raise_read_timeout
    d = create_driver(%[
                        endpoint_url http://#{HTTP_HOST}:#{HTTP_PORT}/read_timeout
                        http_read_timeout 1
                      ])
    d.emit([1, 2], FIXED_TIME)
    assert_raise(Timeout::Error) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Timeout::Error/).count, 1
  end

  def test_raise_error_retry
    d = create_driver(%[endpoint_url http://#{HTTP_HOST}:#{HTTP_PORT}/500])
    d.emit([1, 2], FIXED_TIME)
    assert_raise(RuntimeError) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Retry\. Due to HTTP status was 500\./).count, 1

    d = create_driver(%[endpoint_url http://#{HTTP_HOST}:#{HTTP_PORT}/403])
    d.emit([1, 2], FIXED_TIME)
    d.run
    assert_equal 0, $server.results.length # was not raise error (no retry)
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: /).count, 0

    d = create_driver(%[
                      endpoint_url http://#{HTTP_HOST}:#{HTTP_PORT}/403
                      retry_http_statuses 500, 403
                      ])
    d.emit([1, 2], FIXED_TIME)
    assert_raise(RuntimeError) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Retry\. Due to HTTP status was 403\./).count, 1
  end
end

