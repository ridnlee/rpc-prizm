----------------------
-- The tmp module.
-- Lugate is a lua module for building JSON-RPC 2.0 Gateway APIs just inside of your Nginx configuration file.
-- Lugate is meant to be used with [ngx\_http\_lua\_module](https://github.com/openresty/lua-nginx-module) together.
--
-- @classmod tmp.cache.dummy
-- @author Ivan Zinovyev <vanyazin@gmail.com>
-- @license MIT

local Cache = require 'lugate.cache.cache'

local Dummy = setmetatable({}, {__index=Cache})

--- Create new cache instance
-- @param ...
-- @return[type=table] Return cache instance
function Dummy:new(...)
  local arg = {...}
  local cache = setmetatable({}, self)
  self.__index = self

  cache.memory = {}
  cache.expire = {}

  return cache
end

--- Set value to cache
-- @param[type=string] key
-- @param[type=string] value
-- @param[type=number] ttl
function Dummy:set(key, value, ttl)
  ttl = ttl or 3600
  assert(type(key) == "string", "Parameter 'key' is required and should be a string!")
  assert(type(value) == "string", "Parameter 'value' is required and should be a string!")
  assert(type(ttl) == "number", "Parameter 'expire' is required and should be a number!")

  self.memory[key] = value
  self.expire[key] = os.time() + ttl
end

--- Get value from cache
-- @param[type=string] key
-- @return[type=string]
function Dummy:get(key)
  if self.expire[key] and self.expire[key] > os.time() then
    return self.memory[key]
  end

  return nil
end

--- Add value to the set
-- @param[type=string] set
-- @param[type=string] key
function Dummy:sadd(set, key)
  assert(type(set) == "string", "Parameter 'set' is required and should be a string!")
  assert(type(key) == "string", "Parameter 'key' is required and should be a string!")
  self.expire[set] = os.time() + 3600
  self.memory[set] = self.memory[set] or {}
  table.insert(self.memory[set], key)
end

return Dummy