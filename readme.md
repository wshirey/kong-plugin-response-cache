# kong-plugin-response-cache

A Kong plugin that will cache JSON responses in redis

## How it works
When enabled, this plugin will cache JSON response bodies and headers that match the 
specified URI list into redis. The duration for the cached response is set in 
redis and Kong will continue to use the cached response until redis removes it.

The plugin will only cache JSON responses for GET request methods.

## Cache Key computation

The cache key will be a concatentation of the following items, in order, each delimited 
with the `:` character

1. The URI path
1. Query parameter and value (if defined in `config.vary_by_query_parameters`)
1. Header name and value (if defined in `config.vary_by_headers`)

Query strings and headers with multiple values will have those values concatenated
and command delimited. See the table below for some examples of requests and
their corresponding cache key.

Query strings and headers are concatenated in the cache key in alphabetical order.

request|cache key
---|---
`curl /v1/users/wshirey?is_active`|`/v1/users/wshirey:is_active=true`
`curl /v1/users/wshirey?foo=bar&is_active`|`/v1/users/wshirey:fizz=buzz:is_active=true`
`curl /v1/users/wshirey?foo=bar&foo=baz`|`/v1/users/wshirey:foo=bar,baz`
`curl -H "X-Custom-ID: 123" /v1/users/wshirey?is_active=true`|`/v1/users/wshirey:is_active=true:x-custom-id=123`
`curl -H "X-Custom-ID: 123" -H "X-User-ID: 456" /v1/users/wshirey?is_active=true`|`/v1/users/wshirey:is_active=true:x-custom-id=123:x-user-id=456`
`curl -H "X-Custom-ID: 123" -H "X-Custom-ID: 456" /v1/users/wshirey?is_active=true`|`/v1/users/wshirey:is_active=true:x-custom-id=123,456`

## Configuration

Similar to the built-in JWT Kong plugin, you can associate the jwt-claims-headers
plugin with an api with the following request

```bash
curl -X POST http://kong:8001/apis/{api_name_or_id}/plugins \
  --data "name=response-cache" \
  --data "config.cache_policy.uris=/echo,/headers" \
  --data "config.cache_policy.vary_by_query_parameters=" \
  --data "config.cache_policy.vary_by_headers=X-Custom-ID" \
  --data "config.cache_policy.duration_in_seconds=3600" \
  --data "config.redis_host=127.0.0.1" \
```

form parameter|required|description
---|---|---
`name`|*required*|The name of the plugin to use, in this case: `response-cache`
`cache_policy.uris`|*required*|A comma delimited list of URIs that Kong will cache responses. Supports regular expressions.
`cache_policy.vary_by_query_parameters`|*optional*|A comma delimited list of query parameters to use to compute cache key.
`cache_policy.vary_by_headers`|*optional*|A comma delimited list of headers to use to compute cache key.
`cache_policy.duration_in_seconds`|*required*|The amount of time in seconds that a response will be cached in redis (using the redis [EXPIRE](https://redis.io/commands/expire) command). Redis will be responsible from removing cached responses.
`redis_host`|*required*|The hostname or IP address of the redis server.
`redis_timeout`|*required*|The timeout in milliseconds for the redis connection. Defaults to 2000 milliseconds.
`redis_port`|*optional*|The port of the redis server. Defaults to 6379.
`redis_password`|*optional*|The password (if required) to authenticate to the redis server.
