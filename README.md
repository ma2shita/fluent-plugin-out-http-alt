# fluent-plugin-out-http-alt, a plugin for [Fluentd](http://fluentd.org)

A generic [fluentd][1] output plugin for sending logs to an HTTP endpoint /w buffered.

## Configuration options

    <match *>
      type http_alt
      ((buffer_params))
      endpoint_url    http://localhost.local/api/
      append_tag_to_endpoint_url true # default false | http://localhost.local/api/TAGNAME
      http_open_timeout 10 # default 60 (seconds)
      http_read_timeout 10 # default 60 (seconds)
      retry_http_statuses "404,500" # default 404,408,413,414,500,503
    </match>

## TODOs

* Implement to proxy
* Implement to TLS params
* Implement to msgpack serialized
* Implement to redirect
* Implement to in/out\_forward wire-protocol

----

  [1]: http://fluentd.org/

References:

  * https://github.com/ento/fluent-plugin-out-http
  * https://github.com/ablagoev/fluent-plugin-out-http-buffered

