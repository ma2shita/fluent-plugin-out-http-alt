# coding: utf-8
require "helper"

class HttpErrorRaiseTest < Test::Unit::TestCase
  DEFAULT_CONF = %[
    retry_http_statuses 404,408,413,414,500,503
  ]
  FIXED_TIME = Time.parse("2014-11-25 10:00:01").to_i
  FIXED_TAG = "test"

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf, tag)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::HttpErrorRaise, tag).configure(conf)
  end

  def test_emit
    d = create_driver DEFAULT_CONF, "_http_error_raise.200"
    d.emit([1, 2], FIXED_TIME)
    d.run
    logs = d.instance.log.logs
    assert_equal logs.length, 4
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send to #{d.instance.endpoint(FIXED_TAG)}, /).count, 1
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send success, /).count, 1
    assert_equal logs.grep(/ \[debug\]: out_http_alt: /).count, 2
  end

  def test_emit_with_tag
    d = create_driver DEFAULT_CONF, "_http_error_raise.200"
    d.emit([1, 2], FIXED_TIME)
    d.run
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send to #{d.instance.endpoint(FIXED_TAG)}, /).count, 1
  end

  def test_multiple_buffering_single_emit
    d = create_driver DEFAULT_CONF, "_http_error_raise.200"
    d.emit([1, 2], FIXED_TIME)
    d.run
    d.run
    logs = d.instance.log.logs
    assert_equal logs.length, 8
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send to #{d.instance.endpoint(FIXED_TAG)}, /).count, 2
    assert_equal logs.grep(/ \[info\]: out_http_alt: Send success, /).count, 2
    assert_equal logs.grep(/ \[debug\]: out_http_alt: /).count, 4
  end

  def test_raise_error_cannot_server_connect
    d = create_driver DEFAULT_CONF, "_http_error_raise.refused"
    d.emit([1, 2], FIXED_TIME)
    assert_raise(Errno::ECONNREFUSED) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Connection refused/).count, 1
  end

  def test_raise_read_timeout
    d = create_driver DEFAULT_CONF, "_http_error_raise.timeout"
    d.emit([1, 2], FIXED_TIME)
    assert_raise(Timeout::Error) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Timeout::Error/).count, 1
  end

  def test_raise_error_retry
    d = create_driver DEFAULT_CONF, "_http_error_raise.500"
    d.emit([1, 2], FIXED_TIME)
    assert_raise(RuntimeError) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Retry\. Due to HTTP status was 500\./).count, 1

    d = create_driver %[retry_http_statuses 403], "_http_error_raise.403"
    d.emit([1, 2], FIXED_TIME)
    assert_raise(RuntimeError) { d.run }
    logs = d.instance.log.logs
    assert_equal logs.grep(/ \[warn\]: out_http_alt: Retry\. Due to HTTP status was 403\./).count, 1
  end
end

