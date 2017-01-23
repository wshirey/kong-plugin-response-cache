# kong-plugin-response-cache

A Kong plugin that will cache responses in redis

## How it works
When enabled, this plugin will cache response bodies and headers that match the 
specified URI list into redis. The duration for the cached response is set in 
redis and Kong will continue to use the cached response until redis remove it.

## Configuration

Similar to the built-in JWT Kong plugin, you can associate the jwt-claims-headers
plugin with an api with the following request

```bash
curl -X POST http://kong:8001/apis/{api_name_or_id}/plugins \
  --data "name=response-cache" \
  --data "config.cache_policy.uris=/echo,/headers" \
  --data "config.cache_policy.duration_in_seconds=3600" \
  --data "config.redis_host=127.0.0.1" \
```

form parameter|required|description
---|---|---
`name`|*required*|The name of the plugin to use, in this case: `response-cache`
`cache_policy.uris`|*required*|A list of URIs that Kong will cache responses.
`cache_policy.duration_in_seconds`|*required*|The amount of time in seconds that a response will be cached in redis (using the redis [EXPIRE](https://redis.io/commands/expire) command). Redis will be responsible from removing cached responses.
`redis_host`|*required*|The hostname or IP address of the redis server.
`redis_timeout`|*required*|The timeout in milliseconds for the redis connection. Defaults to 2000 milliseconds.
`redis_port`|*optional*|The port of the redis server. Defaults to 6379.
`redis_password`|*optional*|The password (if required) to authenticate to the redis server.
