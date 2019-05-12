local ResponseBuilder = require ".response_builder"

local HttpStatuses = require '.http_statuses'

local Proxy = {
    REQ_PREF = 'REQ', -- Request prefix (used in log message)
    RESP_PREF = 'RESP', -- Response prefix (used in log message)
}

function Proxy:new(ngx, logger)
    local proxy = setmetatable({}, Proxy)
    self.__index = self

    proxy.ngx = ngx
    proxy.logger = logger

    return proxy

end

function Proxy:do_requests(map_requests)
    local ngx_requests, request_groups = self:get_ngx_requests(map_requests)
    local ngx_responses = { self.ngx.location.capture_multi(ngx_requests) }
    local rpc_responses = self:handle_responses(ngx_responses, request_groups)

    return rpc_responses
end

---
function Proxy:get_ngx_requests(map_requests)
    local ngx_requests = {}
    local request_groups = {}
    for addr,requests in pairs(map_requests) do
        table.insert(request_groups, {addr=addr, reqs=requests})
        table.insert(ngx_requests, self:get_ngx_request(addr, requests))
    end

    return ngx_requests, request_groups
end

--- Build a request in format acceptable by nginx
-- @param[type=table] uri request uri
-- @return[type=table] requests list of rpc requests
function Proxy:get_ngx_request(addr, requests)
    local rpc_requests = {}
    for _,request in ipairs(requests) do
        table.insert(rpc_requests, request:get_body())
    end

    local body = ''
    if #requests > 1 then
        body = '[' .. table.concat(rpc_requests, ",") .. ']'
    else
        body = rpc_requests[1]
    end
    return { addr, { method = 8, body = body, args = self.ngx.req.get_uri_args() } }
end

--- Handle every single response
-- @param[type=number] n Response number
-- @param[type=table] response Response object
-- @return[type=boolean]
function Proxy:handle_responses(ngx_responses, request_groups)
    local responses = {}
    for i, response in ipairs(ngx_responses) do
        -- HTTP code <> 200
        if self.ngx.HTTP_OK ~= response.status then
            local response_msg = HttpStatuses[response.status] or 'Unknown error'
            local data = self.ngx.HTTP_INTERNAL_SERVER_ERROR == response.status and self:clean_response(response.body) or nil
            for _,request in ipairs(request_groups[i]['reqs']) do
                table.insert(responses,  ResponseBuilder:build_json_error(response.status, response_msg, data, request:get_id()))
            end
            -- HTTP code == 200
        else
            local resp_body = self:clean_response(response.body)
            -- Quick way to find invalid responses
            local first_char = string.sub(resp_body, 1, 1)
            local last_char = string.sub(resp_body, -1)

            -- JSON check
            if ('' == resp_body) or ('{' ~= first_char and '[' ~= first_char) or ('}' ~= last_char and ']' ~= last_char) then
                for _, request in ipairs(request_groups[i]['reqs']) do
                    table.insert(responses,  ResponseBuilder:build_json_error(
                            ResponseBuilder.ERR_SERVER_ERROR, 'Server error. Bad JSON-RPC response.', nil, request:get_id()
                    ))
                end
            else
                table.insert(responses, self:trim_brackets(resp_body))
                -- Push to log
                self.logger:write_log(self:trim_brackets(resp_body), Proxy.RESP_PREF)
            end
        end
    end

    return responses
end

--- Clean response (trim)
function Proxy:clean_response(response)
    local response_body = response.body or response
    return response_body:match'^()%s*$' and '' or response_body:match'^%s*(.*%S)'
end

---
function Proxy:trim_brackets(str)
    local _, i1 = string.find(str,'^%[*')
    local i2 = string.find(str,'%]*$')
    return string.sub(str, i1 + 1, i2 - 1)
end

return Proxy