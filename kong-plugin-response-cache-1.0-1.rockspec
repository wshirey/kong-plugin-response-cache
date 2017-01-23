package = "kong-plugin-response-cache"
version = "1.0-1"
source = {
  url = "http://github.com/wshirey/kong-plugin-response-cache"
}
description = {
  summary = "A Kong plugin that will cache responses in redis",
  license = "MIT"
}
dependencies = {
  "lua ~> 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.response-cache.handler"] = "handler.lua",
    ["kong.plugins.response-cache.schema"]  = "schema.lua"
  }
}