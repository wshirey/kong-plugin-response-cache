local BasePlugin = require "kong.plugins.base_plugin"
local CacheHandler = BasePlugin:extend()
local responses = require "kong.tools.responses"
local req_get_method = ngx.req.get_method

local redis = require "resty.redis"
local header_filter = require "kong.plugins.response-transformer.header_transformer"
local is_json_body = header_filter.is_json_body

local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local CACHE_HEADER = 'X-Kong-Cache-Status'

local status_code_bypass = { ngx.HTTP_BAD_GATEWAY, ngx.HTTP_SERVICE_UNAVAILABLE, ngx.HTTP_GATEWAY_TIMEOUT, ngx.HTTP_INTERNAL_SERVER_ERROR, ngx.HTTP_METHOD_NOT_IMPLEMENTED }

local function cacheable_request(method, uri, conf, status_code)
  if method ~= "GET" then
    return false
  end
  
  for _,v in ipairs(status_code_bypass) do
    if v == status_code then
      return false
    end
  end

  for _,v in ipairs(conf.cache_policy.uris) do
    if string.match(uri, "^"..v.."$") then
      return true
    end
  end

  return false
end

local function get_cache_key(uri, headers, query_params, conf)
  local cache_key = uri
  
  table.sort(query_params)
  for _,param in ipairs(conf.cache_policy.vary_by_query_string_parameters) do
    local query_value = query_params[param]
    if query_value then
      if type(query_value) == "table" then
        table.sort(query_value)
        query_value = table.concat(query_value, ",")
      end
      ngx.log(ngx.NOTICE, "varying cache key by query string ("..param..":"..query_value..")")
      cache_key = cache_key..":"..param.."="..query_value
    end
  end

  table.sort(headers)
  for _,header in ipairs(conf.cache_policy.vary_by_headers) do
    local header_value = headers[header]
    if header_value then
      if type(header_value) == "table" then
        table.sort(header_value)
        header_value = table.concat(header_value, ",")
      end
      ngx.log(ngx.NOTICE, "varying cache key by matched header ("..header..":"..header_value..")")
      cache_key = cache_key..":"..header.."="..header_value
    end
  end
  
  return cache_key
end

local function json_decode(json)
  if json then
    local status, res = pcall(cjson_decode, json)
    if status then
      return res
    else 
      ngx.log(ngx.ERR, "[response-cache] error decoding json: ", status, res)
    end
  end
end

local function json_encode(table)
  if table then
    local status, res = pcall(cjson_encode, table)
    if status then
      return res
    else
      ngx.log(ngx.ERR, "[response-cache] error encoding json: ", status, res)
    end
  end
end

local function connect_to_redis(conf)
  local red = redis:new()
  
  red:set_timeout(conf.redis_timeout)
  
  local ok, err = red:connect(conf.redis_host, conf.redis_port)
  if err then
    return nil, err
  end

  if conf.redis_password and conf.redis_password ~= "" then
    local ok, err = red:auth(conf.redis_password)
    if err then
      return nil, err
    end
  end
  
  return red
end

local function red_set(premature, key, val, conf)
  local red, err = connect_to_redis(conf)
  if err then
      ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
  end

  red:init_pipeline()
  red:set(key, val)
  if conf.cache_policy.duration_in_seconds then
    red:expire(key, conf.cache_policy.duration_in_seconds)
  end
  local results, err = red:commit_pipeline()
  if err then
    ngx_log(ngx.ERR, "failed to commit the pipelined requests: ", err)
  end
end

function CacheHandler:new()
  CacheHandler.super.new(self, "response-cache")
end

function CacheHandler:access(conf)
  CacheHandler.super.access(self)
  
  local uri = ngx.var.uri
  local cache_status
  if not cacheable_request(req_get_method(), uri, conf, ngx.status) then
    ngx.log(ngx.NOTICE, "not cacheable")
    cache_status = 'NOCACHE'
    return
  end
  
  local cache_key = get_cache_key(uri, ngx.req.get_headers(), ngx.req.get_uri_args(), conf)  
  local red, err = connect_to_redis(conf)
  if err then
    ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
    return
  end

  local cached_val, err = red:get(cache_key)
  if cached_val and cached_val ~= ngx.null then
    ngx.log(ngx.NOTICE, "cache hit")
    cache_status = 'HIT'
    local val = json_decode(cached_val)
    for k,v in pairs(val.headers) do
      ngx.header[k] = v
    end
    ngx.header[CACHE_HEADER] = cache_status
    ngx.status = val.status_code
    ngx.print(val.content)
    return ngx.exit(val.status_code)
  end

  ngx.log(ngx.NOTICE, "cache miss")
  cache_status = 'MISS'
  ngx.ctx.rt_body_chunks = {}
  ngx.ctx.rt_body_chunk_number = 1
  ngx.header[CACHE_HEADER] = cache_status
  ngx.ctx.response_cache = {
    cache_key = cache_key,
    cache_status = cache_status
  }
end

function CacheHandler:header_filter(conf)
  CacheHandler.super.header_filter(self)

  local ctx = ngx.ctx.response_cache
  if not ctx then
    return
  end

  ctx.headers = ngx.resp.get_headers()
end

function CacheHandler:body_filter(conf)
  CacheHandler.super.body_filter(self)

  local ctx = ngx.ctx.response_cache
  if not ctx then
    return
  end
  
  local chunk, eof = ngx.arg[1], ngx.arg[2]
  local rt_body_chunks = ngx.ctx.rt_body_chunks
  local rt_body_chunk_number = ngx.ctx.rt_body_chunk_number

  if eof then
      local body = table.concat(rt_body_chunks)
      ngx.arg[1] = body
      local value = { content = body, headers = ctx.headers, status_code = ngx.status }
      local value_json = json_encode(value)
      local ok, err = ngx.timer.at(0, red_set, ctx.cache_key, value_json, conf)
      if not ok then
        ngx.log(ngx.ERR, "[response-cache] failed to create timer: ", err)
      end
  else
      rt_body_chunks[rt_body_chunk_number] = chunk
      rt_body_chunk_number = rt_body_chunk_number + 1
      ngx.arg[1] = nil
      ngx.ctx.rt_body_chunks = rt_body_chunks
      ngx.ctx.rt_body_chunk_number = rt_body_chunk_number
  end
end

CacheHandler.PRIORITY = 10

return CacheHandler