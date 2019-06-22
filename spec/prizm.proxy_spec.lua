-- Load the module
local Proxy = dofile("./prizm/proxy.lua")
local Logger = dofile("./prizm/logger.lua")
local Request = dofile("./prizm/request.lua")
local ResponseBuilder = dofile("./prizm/response_builder.lua")
local Json = require "cjson"

describe("Check response validation", function()
    local ngx = { req = {}, HTTP_OK = 200, HTTP_INTERNAL_SERVER_ERROR = 500 }
    ngx.req.get_uri_args = function()
        return {}
    end
    local response_builder = ResponseBuilder:new(Json)
    local logger = Logger:new(ngx, false)
    local proxy = Proxy:new(ngx, logger, response_builder)
    local data = {
        jsonrpc = '2.2',
        method = 'method.name',
        params = {
            one = 1, two = 2
        },
        id = 1,
    }
    local request = Request:new(data, Json)
    local request_group = {addr='/',reqs={request}}
    it("Should provide a valid HTTP error status", function()
        local bad_response = {
            status = 504,
            body = [[
<!DOCTYPE html>
<html>
<head>
<title>Error</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>An error occurred.</h1>
<p>Sorry, the page you are looking for is currently unavailable.<br/>
Please try again later.</p>
<p>If you are the system administrator of this resource then you should check
the <a href="http://nginx.org/r/error_log">error log</a> for details.</p>
<p><em>Faithfully yours, nginx.</em></p>
</body>
</html>
]],
        }
        local responses = proxy:handle_responses({bad_response}, {request_group})
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"504 Gateway Timeout","data":'..Json.encode(proxy:clean_response(bad_response.body))..'},"id":1}', responses[1])
    end)

    it("Should throw an error on invalid JSON with 200 HTTP status", function()
        local bad_response = {
            status = 200,
            body = [[
<!DOCTYPE html>
<html>
<head>
<title>Error</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>An error occurred.</h1>
<p>Sorry, the page you are looking for is currently unavailable.<br/>
Please try again later.</p>
<p>If you are the system administrator of this resource then you should check
the <a href="http://nginx.org/r/error_log">error log</a> for details.</p>
<p><em>Faithfully yours, nginx.</em></p>
</body>
</html>
]],
        }

        local responses = proxy:handle_responses({bad_response}, {request_group})
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error. Bad JSON-RPC response.","data":null},"id":1}', responses[1])
    end)

    it("Should return the page content in data field if HTTP status code is 500", function()
        local bad_response = {
            status = 500,
            body = [[
            Warning: Uncaught exception "PDOException" with message 'SQLSTATE[HY000] [2002] 'Can't connect to [localhost:3306]
            ]],
        }
        local responses = proxy:handle_responses({bad_response}, {request_group})
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"500 Internal Server Error","data":'..Json.encode(proxy:clean_response(bad_response.body))..'},"id":1}', responses[1])
    end)

    it("Should not break on broken JSON object when handling 500 error", function()
        local bad_response = {
            status = 500,
            body = [[
        {"jsonrpc": "2.0", "method"
      ]],
        }
        local responses = proxy:handle_responses({bad_response}, {request_group})
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"500 Internal Server Error","data":'..Json.encode(proxy:clean_response(bad_response.body))..'},"id":1}', responses[1])
    end)

    it("Should pass thought valid error messages", function()
        local valid_error_response = {
            status = 200,
            body = '{"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": 1}',
        }
        local responses = proxy:handle_responses({valid_error_response}, {request_group})
        assert.equals(valid_error_response.body, responses[1])
    end)

    it("Should pass thought valid result messages", function()
        local valid_result_response = {
            status = 200,
            body = '{"jsonrpc": "2.0", "result": ["hello", 5], "id": "9"}',
        }
        local responses = proxy:handle_responses({valid_result_response}, {request_group})
        assert.equals(valid_result_response.body, responses[1])
    end)
end)
