-- Load the module
local ResponseBuilder = dofile("./prizm/response_builder.lua")

describe("Check json rpc error builder", function()
    local builder = ResponseBuilder:new(require "cjson")
    local data_provider = {
        { { ResponseBuilder.ERR_PARSE_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Invalid JSON was received by the server. An error occurred on the server while parsing the JSON text.","data":{}},"id":1}', },
        { { ResponseBuilder.ERR_INVALID_REQUEST, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32600,"message":"The JSON sent is not a valid Request object.","data":{}},"id":1}', },
        { { ResponseBuilder.ERR_METHOD_NOT_FOUND, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32601,"message":"The method does not exist / is not available.","data":{}},"id":1}', },
        { { ResponseBuilder.ERR_INVALID_PARAMS, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32602,"message":"Invalid method parameter(s).","data":{}},"id":1}', },
        { { ResponseBuilder.ERR_INTERNAL_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32603,"message":"Internal JSON-RPC error.","data":{}},"id":1}', },
        { { ResponseBuilder.ERR_SERVER_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error","data":{}},"id":1}', },
        { { ResponseBuilder.ERR_SERVER_ERROR, nil, {}, 1 }, '{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error","data":{}},"id":1}', },
    }

    it("Method build_json_error should be able to build a correct error message", function()
        for _, data in ipairs(data_provider) do
            assert.equals(data[2], builder:build_json_error(data[1][1], data[1][2], data[1][3], data[1][4]))
        end
    end)

    it("Method build_json_error should be able to build an error message with empty input", function()
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"Server error","data":null},"id":null}',
                builder:build_json_error())
    end)

    it("Method build_json_error should be able to build an error message with a custom input", function()
        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"","data":{"foo":"bar"}},"id":100500}',
                builder:build_json_error(0, "", { foo = "bar" }, 100500))

        assert.equals('{"jsonrpc":"2.0","error":{"code":-32000,"message":"Non-empty message","data":null},"id":null}',
                builder:build_json_error({}, "Non-empty message", nil, nil))
    end)
end)
