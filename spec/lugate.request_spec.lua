package.path = package.path .. ";../lugate/?.lua"
-- Load the module
local Request = dofile("./request.lua")

describe("Check request constructor", function()
  it("Request should be initialized", function()
    assert.is_not_nil(Request)
  end)

  it("Error should be thrown if data is not provided", function()
    assert.has_error(function()
      Request:new(nil, {})
    end, "Parameter 'data' is required and should be a table!")
  end)

  it("Error should be thrown if lugate is not provided", function()
    assert.has_error(function()
      Request:new({}, nil)
    end, "Parameter 'lugate' is required and should be a table!")
  end)

  it("The lugate instance should be a table", function()
    assert.is_table(Request:new({}, {}))
  end)
end)

describe("Check request validation", function()

  it("Request should be cachable if ttl and key are given", function()
    local request1 = Request:new({ params = { cache = { key = 'foo', ttl = 123 } } }, {})
    assert.is_true(request1:is_cachable())

    local request2 = Request:new({ params = { cache = { key = 'foo', ttl = 0 } } }, {})
    assert.is_true(request2:is_cachable())

    local request3 = Request:new({ params = { cache = { key = 'foo', ttl = 0, tags = {'foo', 'bar'} } } }, {})
    assert.is_true(request3:is_cachable())
  end)

  it("Request should NOT be cachable if ttl or key are nil", function()
    local request1 = Request:new({ params = { key = 'foo' } }, {})
    assert.is_false(request1:is_cachable())

    local request2 = Request:new({ params = { ttl = 123 } }, {})
    assert.is_false(request2:is_cachable())

    local request3 = Request:new({ params = { ttl = false } }, {})
    assert.is_false(request3:is_cachable())

    local request4 = Request:new({ params = { ttl = false } }, {})
    assert.is_false(request4:is_cachable())

    local request5 = Request:new({ params = { cache = { ttl = false, tags = {'foo', 'bar'} } } }, {})
    assert.is_false(request5:is_cachable())
  end)

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
        route = 'v1.foo.bar'
      }
    }, {})
    assert.is_true(request:is_proxy_call())
  end)

  it("Request should be a invalid proxy call if wrong options are provided", function()
    local request = Request:new({
      jsonrpc = '2.0',
      method = 'foo.bar',
      params = { foo = "bar" }
    }, {})
    assert.is_false(request:is_proxy_call())
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
        cache = {
          ttl = false,
          key = 'd88d8ds00-s',
          tags = {'foo', 'bar'},
        },
        params = { one = 1, two = 2 }
      }
    }, {})
    assert.equal('v1.method.name', request:get_route())
    assert.equal(false, request:get_ttl())
    assert.equal('d88d8ds00-s', request:get_key())
    assert.same({'foo', 'bar'}, request:get_tags())
  end)
end)

describe('Check that uri is created correctly', function()
  local lugate = {
    routes = {
      ['^v2%..*'] = '/api/v2/'
    },
    json = require "rapidjson"
  }
  it("Should provide a correct uri if route matches", function()
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
    local request = Request:new(data, lugate)
    local uri, err = request:get_uri()
    assert.equal('/api/v2/', uri)
    assert.is_nil(err)
  end)
  it("Should not provide a correct uri if the route doesn not match", function()
    local data = {
      jsonrpc = '2.2',
      method = 'method.name',
      params = {
        route = 'v1.method.name',
        cache = {
          ttl = false,
          key = 'd88d8ds00-s',
        },
        params = { one = 1, two = 2 }
      },
      id = 1,
    }
    local request = Request:new(data, lugate)
    local uri, err = request:get_uri()
    assert.equal('Failed to bind the route', err)
    assert.is_nil(uri)
  end)
end)

describe("Check data and body builders", function()
  local lugate = {
    routes = {
      ['^v2%..*'] = '/api/v2/'
    },
    json = require "rapidjson"
  }

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
    local request = Request:new(data, lugate)
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
        request:get_ngx_request()[1])
      assert.equal(canonical_ngx_request[2].method,
        request:get_ngx_request()[2].method)
      assert.are_same(lugate.json.decode(canonical_ngx_request[2].body),
        lugate.json.decode(request:get_ngx_request()[2].body))
    end)

    it("Should provide a valid data table if the data is valid", function()
      assert.are_same({ id = 1, jsonrpc = '2.2', method = 'method.name', params = { one = 1, two = 2 } },
        request:get_data())
    end)
  end)

  describe("Check a negative case", function()
    local data = {}
    local request = Request:new(data, lugate)

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