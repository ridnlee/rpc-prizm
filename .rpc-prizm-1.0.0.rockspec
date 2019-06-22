package = "rpc-prizm"
version = "1.0.0"
source = {
  url = "git://github.com/Ridnlee/rpc-prizm",
  tag = "1.0.0",
}
description = {
  summary = "A package for building JSON-RPC 2.0 Gateway with nginx and lua",
  detailed = [[
      RPC-Prizm is a reverse proxy over OpenResty Lua NGINX module.
      This package parse, rebuild, route requests for JSON-RPC 2.0.
    ]],
  homepage = "http://github.com/Ridnlee/rpc-prizm",
  license = "MIT",
}
dependencies = {
  "lua >= 5.1",
}
build = {
  type = "builtin",
  modules = {
    rpc-prizm = "src/prizm.lua",
    ["rpc-prizm.request"] = "src/rpc-prizm/request.lua",
    ["rpc-prizm.logger"] = "src/rpc-prizm/logger.lua",
    ["rpc-prizm.proxy"] = "src/rpc-prizm/proxy.lua",
    ["rpc-prizm.response_builder"] = "src/rpc-prizm/response_builder.lua",
    ["rpc-prizm.router"] = "src/rpc-prizm/router.lua",
    ["rpc-prizm.http_statuses"] = "src/rpc-prizm/http_statuses.lua",
  },
}