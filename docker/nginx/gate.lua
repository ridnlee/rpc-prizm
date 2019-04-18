-- Print responses out -- Load lugate module
local Lugate = require ".lugate"

-- Get new tmp instance
local lugate = Lugate:init({
    json = require "rapidjson",
    ngx = ngx,
    routes = {
        ['v1%.([^%.]+).*'] = '/v1', -- v1.math.subtract -> /v1.math
        ['v2%.([^%.]+).*'] = '/v2', -- v2.math.addition -> /v2.math
    },
    hooks = {

    },
    debug = true,

})

-- Send multi requst and get multi response
lugate:run()
lugate:print_responses()