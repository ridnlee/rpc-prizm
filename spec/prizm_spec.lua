local Prizm = dofile("./prizm/prizm.lua")
local Router = dofile("./prizm/router.lua")
local Logger = dofile("./prizm/logger.lua")
local Proxy = dofile("./prizm/proxy.lua")
local ResponseBuilder = dofile("./prizm/response_builder.lua")

describe("Check body and data analysis", function()
    it("Method get_body() should return empty string when no body is provided", function()
        local ngx = {}
        local prizm = Prizm:new({ ngx = ngx, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.equals('', prizm:get_body())

        ngx.req = {
            get_body_data = function()
                return 'foo'
            end
        }

        assert.equals('', prizm:get_body())
    end)

    it("Method get_body() should always return a raw body", function()
        local ngx = {
            req = {
                get_body_data = function()
                    return 'foo'
                end
            }
        }
        local prizm = Prizm:new({ ngx = ngx, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.equals('foo', prizm:get_body())
    end)

    it("Method get_data() should return nil if bad json body is provided", function()
        local ngx = {
            req = {
                get_body_data = function()
                    return 'foo'
                end
            }
        }
        local prizm = Prizm:new({ ngx = ngx, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.are_same({}, prizm:get_data())
    end)

    it("Method get_data() should decode a correctly formatted json body", function()
        local ngx = {
            req = {
                get_body_data = function()
                    return '{"foo":"bar"}'
                end
            }
        }
        local prizm = Prizm:new({ ngx = ngx, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.are_same({ foo = "bar" }, prizm:get_data())
    end)

    it("Method is_batch() should return true if valid batch is provided", function()
        local ngx1 = { req = {}, }
        ngx1.req.get_body_data = function()
            return '[{ "foo": "bar" }]'
        end
        local prizm1 = Prizm:new({ ngx = ngx1, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.is_true(prizm1:is_batch())
    end)

    it("Method is_batch() false on single request", function()
        local ngx2 = { req = {} }
        ngx2.req.get_body_data = function()
            return '{ "foo": "bar" }'
        end
        local prizm2 = Prizm:new({ ngx = ngx2, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.is_false(prizm2:is_batch())
    end)

    it("Method is_batch() should return false on nil", function()
        local ngx3 = { req = {} }
        ngx3.req.get_body_data = function()
            return nil
        end
        local prizm3 = Prizm:new({ ngx = ngx3, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.is_false(prizm3:is_batch())
    end)

    it("Method is_batch() should return false on string", function()
        local ngx4 = { req = {} }
        ngx4.req.get_body_data = function()
            return "foo"
        end
        local prizm4 = Prizm:new({ ngx = ngx4, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        assert.is_false(prizm4:is_batch())
    end)
end)

describe("Check request factory", function()
    local ngx = { req = {} }
    it("Should return a single request for a single dimensional table", function()
        local prizm = Prizm:new({ ngx = ngx, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        ngx.req.get_body_data = function()
            return '{"foo":"bar"}'
        end
        assert.equal(1, #prizm:get_requests())
    end)

    it("Should return a multi request for the multi dimensional table", function()
        local prizm = Prizm:new({ ngx = ngx, router = {}, logger = {}, response_builder = {}, proxy = {}, json = require "cjson" })
        ngx.req.get_body_data = function()
            return '[{"foo":"bar"},{"foo":"bar"},{"foo":"bar"}]'
        end
        assert.equal(3, #prizm:get_requests())
    end)
end)

describe("Check request validation", function()
    local ngx = { req = {}, location = {}, HTTP_OK = 200 }
    ngx.location.capture_multi = function()
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

    ngx.req.get_uri_args = function()
        return {}
    end

    ngx.req.get_body_data = function()
        return [[
[
    {"foo": "boo"},
    {"jsonrpc":"2.0","method":"sum","params":[1,2,4],"id": "1"},
    {"jsonrpc":"2.0","method":"s1.qwe","params":{"params":[42,23]},"id":2},
    {"jsonrpc":"2.0","method":"s2.qwe","params":{"params":[42,23]},"id":3}
]
    ]]
    end

    local response_builder = ResponseBuilder:new(require "cjson")
    local logger = Logger:new(ngx, false)
    local proxy = Proxy:new(ngx, logger)
    local prizm = Prizm:new({
        ngx = ngx,
        json = require "cjson",
        logger = Logger:new(ngx, false),
        router = Router:new({
            { rule = 's1%.([^%.]+).*', addr = '/serv1' },
            { rule = 's2%.([^%.]+).*', addr = '/serv2' },
        }),
        response_builder = response_builder, proxy = proxy,
    })

    it("Should provide valid responses", function()
        prizm:run()
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32600,"message":"The JSON sent is not a valid Request object.","data":"{}"},"id":null}', prizm.responses[1])
        assert.is_not_false(string.find(prizm.responses[2], 'Failed to bind the route'))
        assert.equals('{"jsonrpc": "2.0", "result": "Valid response", "id": 2}', prizm.responses[3])
        assert.equals('{"jsonrpc": "2.0", "result": "Valid response", "id": 3}', prizm.responses[4])
    end)
end)

describe("Check one-request batch processing", function()
    local ngx = { req = {}, location = {}, HTTP_OK = 200 }
    ngx.req.get_uri_args = function()
        return {}
    end
    local response_builder = ResponseBuilder:new(require "cjson")
    local logger = Logger:new(ngx, false)
    local proxy = Proxy:new(ngx, logger)
    local prizm = Prizm:new({
        ngx = ngx,
        json = require "cjson",
        logger = Logger:new(ngx, false),
        router = Router:new({
            { rule = 'v1%.([^%.]+).*', addr = '/serv1' },
            { rule = 'v2%.([^%.]+).*', addr = '/serv2' },
            { rule = '.*', addr = '/default' },
        }),
        response_builder = response_builder, proxy = proxy,
    })

    prizm.ngx.location.capture_multi = function()
        return
        {
            status = 200,
            body = '{"jsonrpc": "2.0", "result": "Valid response", "id": 1}',
        }
    end

    prizm.ngx.req.get_body_data = function()
        return '[{"jsonrpc":"2.0","method":"subtract","params":{"cache":{"ttl":3600,"key":"foobar","tags":["news_list","top7"]},"route":"v2.substract","params":[42,23]},"id":1}]'
    end

    it("Should provide a valid batch response with single item inside", function()
        prizm:run()
        assert.equals('[{"jsonrpc": "2.0", "result": "Valid response", "id": 1}]', prizm:get_result())
    end)
end)
