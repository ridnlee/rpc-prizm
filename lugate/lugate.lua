----------------------
-- The tmp module.
-- Lugate is a lua module for building JSON-RPC 2.0 Gateway APIs just inside of your Nginx configuration file.
-- Lugate is meant to be used with [ngx\_http\_lua\_module](https://github.com/openresty/lua-nginx-module) together.
--
-- @classmod tmp
-- @author Ivan Zinovyev <vanyazin@gmail.com>
-- @license MIT

--- Request factory
local Request = require ".request"

local ResponseBuilder = require ".response_builder"

--- The lua gateway class definition
local Lugate = {
  REQ_PREF = 'REQ', -- Request prefix (used in log message)
}

Lugate.HTTP_POST = 8

--- Create new Lugate instance
-- @param[type=table] config Table of configuration options
-- @return[type=table] The new instance of Lugate
function Lugate:new(config)
  config.hooks = config.hooks or {}
  config.hooks.pre = config.hooks.pre or function() end
  config.hooks.pre_request = config.hooks.pre_request or function() end
  config.hooks.post = config.hooks.post or function() end

  assert(type(config.ngx) == "table", "Parameter 'ngx' is required and should be a table!")
  assert(type(config.json) == "table", "Parameter 'json' is required and should be a table!")
  assert(type(config.hooks.pre) == "function", "Parameter 'pre' is required and should be a function!")
  assert(type(config.hooks.post) == "function", "Parameter 'post' is required and should be a function!")

  -- Define metatable
  local lugate = setmetatable({}, Lugate)
  self.__index = self

  -- Define services and configs

  lugate.hooks = config.hooks
  lugate.ngx = config.ngx
  lugate.json = config.json
  lugate.router = config.router
  lugate.logger = config.logger
  lugate.proxy = config.proxy
  lugate.responses = {}
  lugate.context = {}

  return lugate
end

--- Create new Lugate instance. Initialize ngx dependent properties
-- @param[type=table] config Table of configuration options
-- @return[type=table] The new instance of Lugate
function Lugate:init(config)
  -- Create new tmp instance
  local lugate = self:new(config)

  -- Check request method
  if 'POST' ~= lugate.ngx.req.get_method() then
    lugate.ngx.say(ResponseBuilder:build_json_error(ResponseBuilder.ERR_INVALID_REQUEST, 'Only POST requests are allowed'))
    lugate.ngx.exit(lugate.ngx.HTTP_OK)
  end

  -- Build config
  lugate.ngx.req.read_body() -- explicitly read the req body

  if not lugate:is_not_empty() then
    lugate.ngx.say(ResponseBuilder:build_json_error(ResponseBuilder.ERR_EMPTY_REQUEST))
    lugate.ngx.exit(lugate.ngx.HTTP_OK)
  end

  return lugate
end

--- Check if request is empty
-- @return[type=boolean]
function Lugate:is_not_empty()
  return self:get_body() ~= '' and true or false
end

--- Get ngx request body
-- @return[type=string]
function Lugate:get_body()
  if not self.body then
    self.body = self.ngx.req and self.ngx.req.get_body_data() or ''
  end

  return self.body
end

--- Parse raw body
-- @return[type=table]
function Lugate:get_data()
  if not self.data then
    self.data = {}
    if self:get_body() then
      local success, res = pcall(self.json.decode, self:get_body())
      self.data = success and res or {}
    end
  end

  return self.data
end

--- Check if request is a batch
-- @return[type=boolean]
function Lugate:is_batch()
  if not self.batch then
    local data = self:get_data()
    self.batch =  data and data[1] and ('table' == type(data[1])) and true or false
  end

  return self.batch
end

--- Get request collection
-- @return[type=table] The table of requests
function Lugate:get_requests()
  if not self.requests then
    self.requests = {}
    local data = self:get_data()
    if self:is_batch() then
      for _, rdata in ipairs(data) do
        table.insert(self.requests, Request:new(rdata, self.json))
      end
    else
      table.insert(self.requests, Request:new(data, self.json))
    end
  end

  return self.requests
end

--- Get request collection prepared for ngx.location.capture_multi call
-- @return[type=table] The table of requests
function Lugate:run()
  -- Execute 'pre' middleware
  if false == self.hooks.pre(self) then
    return ngx.exit(ngx.HTTP_OK)
  end

  local map_requests = self:prepare_map_requests(self:get_requests())

  if  next(map_requests) ~= nil then
      local proxy_responses  = self.proxy:do_requests(map_requests)
      for _,v in ipairs(proxy_responses) do
          table.insert(self.responses, v)
      end
  end

  -- Execute 'post' middleware
  if false == self.hooks.post(self) then
    return ngx.exit(ngx.HTTP_OK)
  end

  return self.responses
end

---
function Lugate:prepare_map_requests(requests)
    local map_requests = {}

    for _, request in ipairs(requests) do
        self.logger:write_log(request:get_body(), Lugate.REQ_PREF)
        if not request:is_valid() then
            table.insert(self.responses, ResponseBuilder:build_json_error(ResponseBuilder.ERR_INVALID_REQUEST, nil, request:get_body(), request:get_id()));
        end

        local pre_request_result = self.hooks.pre_request(self, request)
        if type(pre_request_result) == 'string' then
            table.insert(self.responses, pre_request_result)
        end

        local addr, err = self.router:get_address(request:get_route())
        if addr then
            map_requests[addr] = map_requests[addr] or {}
            table.insert(map_requests[addr], request)
        else
            table.insert(self.responses,  ResponseBuilder:build_json_error(ResponseBuilder.ERR_SERVER_ERROR, err, request:get_body(), request:get_id()))
        end
    end

    return map_requests;
end

--- Get responses as a string
-- @return[type=string]
function Lugate:get_result()
  if false == self:is_batch() then
    return self.responses[1]
  end

  return '[' .. table.concat(self.responses, ",") .. ']'
end

--- Print all responses and exit
function Lugate:print_responses()
  ngx.say(self:get_result())

  ngx.exit(ngx.HTTP_OK)
end

return Lugate