package.path = "/etc/nginx/lugate/?.lua;" .. package.path
-- Load the module
local Request = require "request"

describe("Check request constructor", function()
  it("Request should be initialized", function()
    assert.is_not_nil(Request)
  end)

  it("Error should be thrown if data is not provided", function()
    assert.has_error(function()
      Request:new(nil, {})
    end, "Parameter 'data' is required and should be a table!")
  end)

  it("Error should be thrown if json_encoder is not provided", function()
    assert.has_error(function()
      Request:new({}, nil)
    end, "Parameter 'json_encoder' is required and should be a table!")
  end)

  it("The request instance should be a table", function()
    assert.is_table(Request:new({}, {}))
  end)
end)

describe("Check request validation", function()

  it("Request should be valid if jsonrpc version and method are provided", function()
    local request = Request:new({ jsonrpc = '2.0', method = 'foo.bar' }, {})
    assert.is_true(request:is_valid())
  end)

  it("Request should be invalid if jsonrpc version and method are provided", function()
    local request = Request:new({ method = 'foo.bar' }, {})
    assert.is_false(request:is_valid())
  end)

  it("Request should be a valid proxy call if params and route values are provided", function()
    local request = Request:new({
      jsonrpc = '2.0',
      method = 'foo.bar',
      params = {
        params = {},
      }
    }, {})
    assert.is_true(request:is_valid())
  end)

end)

describe("Check request params are parsed correctly", function()
  it("Request should contain jsonrpc property if any provided", function()
    local request = Request:new({ jsonrpc = '2.2' }, {})
    assert.equals('2.2', request:get_jsonrpc())
  end)

  it("Request should contain method property if any provided", function()
    local request = Request:new({ method = 'method.name' }, {})
    assert.equals('method.name', request:get_method())
  end)

  it("Request should contain id property if any provided", function()
    local request = Request:new({ id = 2 }, {})
    assert.equals(2, request:get_id())
  end)

  it("Request should contain params property if any provided", function()
    local request = Request:new({ jsonrpc = '2.2', method = 'method.name', params = { one = 1, two = 2 } }, {})
    assert.are_same({ one = 1, two = 2 }, request:get_params())
  end)

  it("Request should contain params property even if they are nested provided", function()
    local request = Request:new({
      jsonrpc = '2.2',
      method = 'method.name',
      params = {
        route = 'v1.method.name',
        params = { one = 1, two = 2 }
      }
    }, {})
    assert.are_same({ one = 1, two = 2 }, request:get_params())
  end)

  it("Request should contain nested proxy params if they are provided", function()
    local request = Request:new({
      jsonrpc = '2.2',
      method = 'method.name',
      params = {
        route = 'v1.method.name',
        params = { one = 1, two = 2 }
      }
    }, {})
    assert.equal('method.name', request:get_route())
  end)
end)

describe("Check data and body builders", function()
  local json_encoder = require "cjson"

  describe("Check a positive case", function()
    local data = {
      jsonrpc = '2.2',
      method = 'method.name',
      params = {
        route = 'v2.method.name',
        cache = {
          ttl = false,
          key = 'd88d8ds00-s',
        },
        params = { one = 1, two = 2 }
      },
      id = 1,
    }
    local request = Request:new(data, json_encoder)
    local canonical_ngx_request = { '/api/v2/', { method = 8, body = '{"jsonrpc":"2.2","params":{"two":2,"one":1},"id":1,"method":"method.name"}' } }

    it("Should provide a valid data table if the data is valid", function()
      assert.are_same({ id = 1, jsonrpc = '2.2', method = 'method.name', params = { one = 1, two = 2 } },
        request:get_data())
    end)

    it("Should provide a valid data table if the data is valid", function()
      assert.not_nil(string.find(request:get_body(), '"jsonrpc":"2.2"'))
      assert.not_nil(string.find(request:get_body(), '"id":1'))
      assert.not_nil(string.find(request:get_body(), '"method":"method.name"'))
      assert.not_nil(string.find(request:get_body(), '"params":{'))
    end)

    it("Should provide a valid ngx data table if the data is valid", function()
      assert.equal(canonical_ngx_request[1],
        request:get_ngx_request('/api/v2/')[1])
      assert.equal(canonical_ngx_request[2].method,
        request:get_ngx_request('/api/v2/')[2].method)
      assert.are_same(json_encoder.decode(canonical_ngx_request[2].body),
        json_encoder.decode(request:get_ngx_request('/api/v2/')[2].body))
    end)

    it("Should provide a valid data table if the data is valid", function()
      assert.are_same({ id = 1, jsonrpc = '2.2', method = 'method.name', params = { one = 1, two = 2 } },
        request:get_data())
    end)
  end)

  describe("Check a negative case", function()
    local data = {}
    local request = Request:new(data, json_encoder)

    it("Should NOT provide a valid data table if the data is invalid", function()
      assert.are_not_same({ id = 1, jsonrpc = '2.0', method = 'method.name', params = { one = 1, two = 2 } },
        request:get_data())
    end)

    it("Should provide a valid data table if the data is valid", function()
      assert.is_nil(string.find(request:get_body(), '"jsonrpc":"2.2"'))
      assert.is_nil(string.find(request:get_body(), '"id":1'))
      assert.is_nil(string.find(request:get_body(), '"method":"method.name"'))
      assert.is_nil(string.find(request:get_body(), '"params":{"two":2,"one":1}'))
    end)

    it("Should NOT provide a valid data table if the data is invalid", function()
      assert.are_not_same({ id = 1, jsonrpc = '2.2', method = 'method.name', params = { one = 1, two = 2 } },
        request:get_data())
    end)
  end)
end)