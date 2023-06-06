local cjson = require("cjson")
local base64 = require("base64")

local logger = require("resty.logger.socket")
if not logger.initted() then
    local ok, err = logger.init{
        path = "/http_mirror_socket_volume/http_socket_server.sock",
        periodic_flush = 1
    }
    if not ok then
        ngx.log(ngx.ERR, "Failed to initialize the logger: ", err)
        return
    end
end

local data = {request={}, response={}}

data["server_addr"] = ngx.var.server_addr
data["server_port"] = ngx.var.server_port
data["remote_addr"] = ngx.var.remote_addr
data["remote_port"] = ngx.var.remote_port
data["scheme"] = ngx.var.scheme
data["body_file"] = ngx.req.get_body_file()

data["request"]["raw_base64"] = base64.encode(ngx.req.raw_header() .. (ngx.ctx.my_request_body or ''))
data["request"]["time"] = ngx.req.start_time()

-- Signature: ngx.resp.get_headers(max_headers?, raw?)
data["response"]["headers"] = ngx.resp.get_headers(1000, true)
data["response"]["body_base64"] = base64.encode(ngx.var.response_body)
data["response"]["duration"] = ngx.var.upstream_response_time
data["response"]["status"] = ngx.status

local msg = cjson.encode(data) .. "\n"

local bytes, err = logger.log(msg)
if err then
    ngx.log(ngx.ERR, "Failed to log message: ", err)
end

