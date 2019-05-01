package.path = "/etc/nginx/lugate/?.lua;" .. package.path
-- Load the module
local Lugate = require "lugate"

describe("Check lugate constructor", function()
  it("Lugate should be initialized", function()
    assert.is_not_nil(Lugate)
  end)

  it("Error should be thrown if ngx is not loaded", function()
    assert.has_error(function()
      Lugate:new({ json = {} })
    end, "Parameter 'ngx' is required and should be a table!")
  end)

  it("Error should be thrown if json is not loaded", function()
    assert.has_error(function()
      Lugate:new({ ngx = {} })
    end, "Parameter 'json' is required and should be a table!")
  end)

  it("The lugate instance should be a table", function()
    assert.is_table(Lugate:new({ ngx = {}, json = {} }))
  end)
end)

describe("Check json rpc error builder", function()
  local lugate = Lugate:new({ ngx = {}, json = require "cjson" })
  local data_provider = {
    { { Lugate.ERR_PARSE_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Invalid JSON was received by the server. An error occurred on the server while parsing the JSON text.","data":{}},"id":1}', },
    { { Lugate.ERR_INVALID_REQUEST, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32600,"message":"The JSON sent is not a valid Request object.","data":{}},"id":1}', },
    { { Lugate.ERR_METHOD_NOT_FOUND, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32601,"message":"The method does not exist / is not available.","data":{}},"id":1}', },
    { { Lugate.ERR_INVALID_PARAMS, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid method parameter(s).","data":{}},"id":1}', },
    { { Lugate.ERR_INTERNAL_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32603,"message":"Internal JSON-RPC error.","data":{}},"id":1}', },
    { { Lugate.ERR_SERVER_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error","data":{}},"id":1}', },
    { { Lugate.ERR_SERVER_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error","data":{}},"id":1}', },
  }

  it("Method build_json_error should be able to build a correct error message", function()
    for _, data in ipairs(data_provider) do
      assert.equals(data[2], lugate:build_json_error(data[1][1], data[1][2], data[1][3], data[1][4]))
    end
  end)

  it("Method build_json_error should be able to build an error message with empty input", function()
    assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error","data":null},"id":null}',
      lugate:build_json_error())
  end)

  it("Method build_json_error should be able to build an error message with a custom input", function()
    assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"","data":{"foo":"bar"}},"id":100500}',
      lugate:build_json_error(0, "", { foo = "bar" }, 100500))

    assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"Non-empty message","data":null},"id":null}',
      lugate:build_json_error({}, "Non-empty message", nil, nil))
  end)
end)

describe("Check body and data analysis", function()
  it("Method get_body() should return empty string when no body is provided", function()
    local ngx = {}
    local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
    assert.equals('', lugate:get_body())

    ngx.req = {
      get_body_data = function()
        return 'foo'
      end
    }

    assert.equals('', lugate:get_body())
  end)

  it("Method get_body() should always return a raw body", function()
    local ngx = {
      req = {
        get_body_data = function()
          return 'foo'
        end
      }
    }
    local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
    assert.equals('foo', lugate:get_body())
  end)

  it("Method get_data() should return nil if bad json body is provided", function()
    local ngx = {
      req = {
        get_body_data = function()
          return 'foo'
        end
      }
    }
    local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
    assert.are_same({}, lugate:get_data())
  end)

  it("Method get_data() should decode a correctly formatted json body", function()
    local ngx = {
      req = {
        get_body_data = function()
          return '{"foo":"bar"}'
        end
      }
    }
    local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
    assert.are_same({ foo = "bar" }, lugate:get_data())
  end)

  it("Method is_batch() should return true if valid batch is provided", function()
    local ngx1 = { req = {},  }
    ngx1.req.get_body_data = function()
      return '[{ "foo": "bar" }]'
    end
    local lugate1 = Lugate:new({ ngx = ngx1, json = require "cjson" })
    assert.is_true(lugate1:is_batch())
  end)

  it("Method is_batch() false on single request", function()
    local ngx2 = { req = {} }
    ngx2.req.get_body_data = function()
      return '{ "foo": "bar" }'
    end
    local lugate2 = Lugate:new({ ngx = ngx2, json = require "cjson" })
    assert.is_false(lugate2:is_batch())
  end)

  it("Method is_batch() should return false on nil", function()
    local ngx3 = { req = {} }
    ngx3.req.get_body_data = function()
      return nil
    end
    local lugate3 = Lugate:new({ ngx = ngx3, json = require "cjson" })
    assert.is_false(lugate3:is_batch())
  end)

  it("Method is_batch() should return false on string", function()
    local ngx4 = { req = {} }
    ngx4.req.get_body_data = function()
      return "foo"
    end
    local lugate4 = Lugate:new({ ngx = ngx4, json = require "cjson" })
    assert.is_false(lugate4:is_batch())
  end)
end)

describe("Check request factory", function()
  local ngx = { req = {} }
  it("Should return a single request for a single dimensional table", function()
    local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
    ngx.req.get_body_data = function()
      return '{"foo":"bar"}'
    end
    assert.equal(1, #lugate:get_requests())
  end)

  it("Should return a multi request for the multi dimensional table", function()
    local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
    ngx.req.get_body_data = function()
      return '[{"foo":"bar"},{"foo":"bar"},{"foo":"bar"}]'
    end
    assert.equal(3, #lugate:get_requests())
  end)
end)

describe("Check response validation", function ()
  local ngx = { req = {}, HTTP_OK = 200, HTTP_INTERNAL_SERVER_ERROR = 500 }
  local lugate = Lugate:new({ ngx = ngx, json = require "cjson" })
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
    lugate.req_dat.num[504] = 504
    lugate.req_dat.ids[504] = 256
    lugate:handle_response(504, bad_response)
    assert.equals('{"jsonrpc":"2.0","error":{"code":504,"message":"Gateway Timeout","data":null},"id":256}', lugate.responses[504])
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
    lugate.req_dat.num[1111] = 1111
    lugate.req_dat.ids[1111] = 16
    lugate:handle_response(1111, bad_response)
    assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error. Bad JSON-RPC response.","data":null},"id":16}', lugate.responses[1111])
  end)


  it("Should return the page content in data field if HTTP status code is 500", function()
    local bad_response = {
      status = 500,
      body = [[
        Warning: Uncaught exception "PDOException" with message 'SQLSTATE[HY000] [2002] 'Can't connect to [localhost:3306]
      ]],
    }
    lugate.req_dat.num[500] = 500
    lugate.req_dat.ids[500] = 16
    lugate:handle_response(500, bad_response)
    assert.equals('{"jsonrpc":"2.0","error":{"code":500,"message":"Internal Server Error","data":"Warning: Uncaught exception \\"PDOException\\" with message \'SQLSTATE[HY000] [2002] \'Can\'t connect to [localhost:3306]"},"id":16}', lugate.responses[500])
  end)

  it("Should not break on broken JSON object when handling 500 error", function()
    local bad_response = {
      status = 500,
      body = [[
        {"jsonrpc": "2.0", "method"
      ]],
    }
    lugate.req_dat.num[1500] = 1500
    lugate.req_dat.ids[1500] = 16
    lugate:handle_response(1500, bad_response)
    assert.equals('{"jsonrpc":"2.0","error":{"code":500,"message":"Internal Server Error","data":"{\\"jsonrpc\\": \\"2.0\\", \\"method\\""},"id":16}', lugate.responses[1500])
  end)

  it("Should pass thought valid error messages", function()
    local valid_error_response = {
      status = 200,
      body = '{"jsonrpc": "2.0", "error": {"code": -32600, "message": "Invalid Request"}, "id": null}',
    }
    lugate.req_dat.num[40] = 40
    lugate.req_dat.ids[40] = 32
    lugate:handle_response(40, valid_error_response)
    assert.equals(valid_error_response.body, lugate.responses[40])
  end)

  it("Should pass thought valid result messages", function()
    local valid_result_response = {
      status = 200,
      body = '{"jsonrpc": "2.0", "result": ["hello", 5], "id": "9"}',
    }
    lugate.req_dat.num[15] = 15
    lugate.req_dat.ids[15] = 32
    lugate:handle_response(15, valid_result_response)
    assert.equals(valid_result_response.body, lugate.responses[15])
  end)
end)

describe("Check request validation", function()
  local ngx = { req = {}, location = {}, HTTP_OK = 200 }
  local lugate = Lugate:new({
    ngx = ngx,
    json = require "cjson",
    routes = {
        {rule='s1%.([^%.]+).*', addr='/serv1'},
        {rule='s2%.([^%.]+).*', addr='/serv2'},
    },
  })

  lugate.ngx.location.capture_multi = function()
    return
      {
        status = 200,
        body = '{"jsonrpc": "2.0", "result": "Valid response", "id": 2}',
      },
      {
        status = 200,
        body = '{"jsonrpc": "2.0", "result": "Valid response", "id": 3}',
      }
  end

  lugate.ngx.req.get_body_data = function()
    return [[
[
    {"jsonrpc":"2.0","method":"sum","params":[1,2,4],"id": "1"},
    {"jsonrpc":"2.0","method":"s1.qwe","params":{"params":[42,23]},"id":2},
    {"foo": "boo"},
    {"jsonrpc":"2.0","method":"s2.qwe","params":{"params":[42,23]},"id":3}
]
    ]]
  end

  it("Should provide valid responses", function()
    lugate:run()
    assert.is_not_false(string.find(lugate.responses[1], 'Failed to bind the route'))
    assert.equals('{"jsonrpc": "2.0", "result": "Valid response", "id": 2}', lugate.responses[2])
    assert.equals('{"jsonrpc":"2.0","error":{"code":-32600,"message":"The JSON sent is not a valid Request object.","data":"{}"},"id":null}', lugate.responses[3])
    assert.equals('{"jsonrpc": "2.0", "result": "Valid response", "id": 3}', lugate.responses[4])
  end)
end)

describe("Check one-request batch processing", function()
  local ngx = { req = {}, location = {}, HTTP_OK = 200 }
  local lugate = Lugate:new({
    ngx = ngx,
    json = require "cjson",
    routes = {
        {rule='v1%.([^%.]+).*', addr='/serv1'},
        {rule='v2%.([^%.]+).*', addr='/serv2'},
        {rule='.*', addr='/default'},
    },
  })

  lugate.ngx.location.capture_multi = function()
    return
    {
      status = 200,
      body = '{"jsonrpc": "2.0", "result": "Valid response", "id": 1}',
    }
  end

  lugate.ngx.req.get_body_data = function()
    return '[{"jsonrpc":"2.0","method":"subtract","params":{"cache":{"ttl":3600,"key":"foobar","tags":["news_list","top7"]},"route":"v2.substract","params":[42,23]},"id":1}]'
  end

  it("Should provide a valid batch response with single item inside", function()
    lugate:run()
    assert.equals('[{"jsonrpc": "2.0", "result": "Valid response", "id": 1}]', lugate:get_result())
  end)
end)
