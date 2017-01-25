return {
  no_consumer = true,
  fields = {
    cache_policy = { 
      type = "table",
      schema = {
        fields = {
          uris = { type = "array", required = true },
          vary_by_query_string_parameters = { type = "array", default = {} },
          vary_by_headers = { type = "array", default = {} },
          duration_in_seconds = { type = "string", required = true }
        }
      }
    },
    redis_host = { type = "string", required = true },
    redis_port = { type = "number", default = 6379 },
    redis_password = { type = "string" },
    redis_timeout = { type = "number", default = 2000 }
  }
}