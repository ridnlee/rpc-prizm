----------------------
-- The tmp module.
-- Lugate is a lua module for building JSON-RPC 2.0 Gateway APIs just inside of your Nginx configuration file.
-- Lugate is meant to be used with [ngx\_http\_lua\_module](https://github.com/openresty/lua-nginx-module) together.
--
-- @classmod tmp.request
-- @author Ivan Zinovyev <vanyazin@gmail.com>
-- @license MIT

--- Request object
local Request = {}

--- Create new request
-- param[type=table] data Request data
-- param[type=table] tmp Lugate instance
-- return[type=table] New request instance
function Request:new(data, lugate)
  assert(type(data) == "table", "Parameter 'data' is required and should be a table!")
  assert(type(lugate) == "table", "Parameter 'tmp' is required and should be a table!")

  local request = setmetatable({}, Request)
  self.__index = self
  request.lugate = lugate
  request.data = data

  return request
end

--- Check if request is valid JSON-RPC 2.0
-- @return[type=boolean]
function Request:is_valid()
  if nil == self.valid then
    self.valid = self.data.jsonrpc
      and self.data.method
      and true or false
  end

  return self.valid
end

--- Get JSON-RPC version
-- @return[type=string]
function Request:get_jsonrpc()
  return self.data.jsonrpc
end

--- Get method name
-- @return[type=string]
function Request:get_method()
  return self.data.method
end

--- Get request params (search for nested params)
-- @return[type=table]
function Request:get_params()
  return self:is_valid() and self.data.params.params or self.data.params
end

--- Get request id
-- @return[type=int]
function Request:get_id()
  return self.data.id
end

--- Get request route
-- @return[type=string]
function Request:get_route()
  return self:is_valid() and self.data.method or nil
end

--- Get request data table
-- @return[type=table]
function Request:get_data()
  return {
    jsonrpc = self:get_jsonrpc(),
    id = self:get_id(),
    method = self:get_method(),
    params = self:get_params()
  }
end

--- Get request body
-- @return[type=string] Json array
function Request:get_body()
  return self.lugate.json.encode(self:get_data())
end

--- Build a request in format acceptable by nginx
-- @param[type=table] uri request uri
-- @return[type=table] ngx request
function Request:get_ngx_request(uri)
    return { uri, { method = 8, body = self:get_body() } }
end

return Request