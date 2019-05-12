-- Load modules
local Lugate = require ".lugate"
local Router = require ".router"
local Logger = require ".logger"
local Jwt = require "resty.jwt"
local Proxy = require ".proxy"

local jwt_key = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv\nvkTtwlvBsaJq7S5wA+kzeVOVpVWwkWdVha4s38XM/pa/yr47av7+z3VTmvDRyAHc\naT92whREFpLv9cj5lTeJSibyr/Mrm/YtjCZVWgaOYIhwrXwKLqPr/11inWsAkfIy\ntvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0\ne+lf4s4OxQawWD79J9/5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb\nV6L11BWkpzGXSW4Hv43qa+GSYOD2QU68Mb59oSk2OB+BtOLpJofmbGEGgvmwyCI9\nMwIDAQAB\n-----END PUBLIC KEY-----'

local router = Router:new({
    {rule='v1%.([^%.]+).*', addr='/serv1'},
    {rule='v2%.([^%.]+).*', addr='/serv2'},
    {rule='.*', addr='/default'},
})

local logger = Logger:new(ngx, true)

local proxy = Proxy:new(ngx, logger)

-- Get new tmp instance
local lugate = Lugate:init({
    json = require "cjson",
    ngx = ngx,
    router = router,
    logger = logger,
    proxy = proxy,
    hooks = {
        pre = function ()
            local auth_header = ngx.var.http_Authorization
            local token = nil
            if auth_header then
                _, _, token = string.find(auth_header, "Bearer%s+(.+)")
            end

            ngx.ctx.jwt_valid = true
            if token == nil then
                ngx.ctx.jwt_valid = false
            else
                local validators = require "resty.jwt-validators"
                local claim_spec = {
                    validators.set_system_leeway(15), -- time in seconds
                    exp = validators.is_not_expired(),
                    iat = validators.is_not_before(),
                    -- iss = validators.equals_any_of({"example.com"}),
                }

                local jwt_obj = Jwt:verify(jwt_key, token, claim_spec)
                if not jwt_obj["verified"] then
                    ngx.ctx.jwt_valid = false
                else
                    --ngx.req.set_header("x-data-user-id", jwt_obj["payload"]["user_id"])
                end
            end

        end,

        pre_request = function (request)
            local auth = {
                ['v2.substract'] = true
            }
            if not ngx.ctx.jwt_valid and auth[request:get_route()] then
                return '{"jsonrpc": "2.0","id": ' .. request:get_id() .. ',"error": {"code": -32099,"message": "Internal error","data": "Access denied"}}'
            end
            return true
        end
    },
})

-- Send multi requst and get multi response
lugate:run()
lugate:print_responses()