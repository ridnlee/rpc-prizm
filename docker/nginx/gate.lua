-- Print responses out -- Load lugate module
local Lugate = require ".lugate"
local Jwt = require "resty.jwt"

local jwt_key = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnzyis1ZjfNB0bBgKFMSv\nvkTtwlvBsaJq7S5wA+kzeVOVpVWwkWdVha4s38XM/pa/yr47av7+z3VTmvDRyAHc\naT92whREFpLv9cj5lTeJSibyr/Mrm/YtjCZVWgaOYIhwrXwKLqPr/11inWsAkfIy\ntvHWTxZYEcXLgAXFuUuaS3uF9gEiNQwzGTU1v0FqkqTBr4B8nW3HCN47XUu0t8Y0\ne+lf4s4OxQawWD79J9/5d3Ry0vbV3Am1FtGJiJvOwRsIfVChDpYStTcHTCMqtvWb\nV6L11BWkpzGXSW4Hv43qa+GSYOD2QU68Mb59oSk2OB+BtOLpJofmbGEGgvmwyCI9\nMwIDAQAB\n-----END PUBLIC KEY-----'

-- Get new tmp instance
local lugate = Lugate:init({
    json = require "cjson",
    ngx = ngx,
    routes = {
        ['v1%.([^%.]+).*'] = '/v1', -- v1.math.subtract -> /v1.math
        ['v2%.([^%.]+).*'] = '/v2', -- v2.math.addition -> /v2.math
    },
    hooks = {
        pre = function ()
            local auth_header = ngx.var.http_Authorization
            local token = nil
            if auth_header then
                _, _, token = string.find(auth_header, "Bearer%s+(.+)")
            end

            if token == nil then
                ngx.status = ngx.HTTP_FORBIDDEN
                ngx.header.content_type = "application/json; charset=utf-8"
                ngx.say('{"jsonrpc": "2.0","id": 1,"error": {"code": -32099,"message": "Internal error","data": "Access denied"}}')
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

            local validators = require "resty.jwt-validators"
            local claim_spec = {
                validators.set_system_leeway(15), -- time in seconds
                exp = validators.is_not_expired(),
                iat = validators.is_not_before(),
                -- iss = validators.equals_any_of({"am.ru", "youla.io", "youla.and", "youla.ios"}),
            }

            local jwt_obj = Jwt:verify(jwt_key, token, claim_spec)
            if not jwt_obj["verified"] then
                ngx.status = ngx.HTTP_FORBIDDEN
                ngx.log(ngx.ERR, jwt_obj.reason)
                ngx.header.content_type = "application/json; charset=utf-8"
                ngx.say('{"jsonrpc": "2.0","id": 1,"error": {"code": -32099,"message": "Internal error","data": "Access denied"}}')
                ngx.exit(ngx.HTTP_FORBIDDEN)
            end

        end
    },
    debug = true,

})

-- Send multi requst and get multi response
lugate:run()
lugate:print_responses()