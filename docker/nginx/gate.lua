-- Print responses out -- Load lugate module
local Lugate = require ".lugate"

-- Get new tmp instance
local lugate = Lugate:init({
    json = require "rapidjson",
    ngx = ngx,
    cache = { 'redis', '127.0.0.1', 6379, 13 }, -- redis, host, port, db num
    routes = {
        ['v1%.([^%.]+).*'] = '/v1', -- v1.math.subtract -> /v1.math
        ['v2%.([^%.]+).*'] = '/v2', -- v2.math.addition -> /v2.math
    },
    hooks = {
        cache = function(lugate, response)
            return (response.header['Cache-control'] == 'no-cache') or false
        end
    },
    debug = true,

})

-- Send multi requst and get multi response
lugate:run()
lugate:print_responses()