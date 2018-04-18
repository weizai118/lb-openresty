local _M = {}




-- ####################### upstream #######################

-- get upstream file path by upstream name
function _M.get_upstream_file(name)
    return dynamic_upstreams_dir.."/"..name..".conf"
end

-- 定义upstream文件模版
_M.temp_upstream =
[[upstream %s {
    %s
}]]

function _M.upstream_save(data_table)
    local name = data_table.name
    local upstream_file = _M.get_upstream_file(name)

    -- 将server列表拼接为多行形式
    local servers_line = ""
    for _, item in pairs(data_table.servers) do
        if servers_line == "" then
            servers_line = string.format("server %s weight=%s;", item.addr, item.weight)
        else
            servers_line = string.format("%s\n    server %s weight=%s;", servers_line, item.addr, item.weight)
        end
    end

    -- 生成完整文件内容
    local content = string.format(_M.temp_upstream, name, servers_line)

    -- 写入文件
    local file = io.open(upstream_file, "w+")
    file:write(content)
    file:close()

    -- 检查文件合法性
    return utils.shell(utils.cmd_check_nginx, "0")
end

function _M.upstream_delete(name)
    local upstream_file = _M.get_upstream_file(name)
    return utils.shell("rm -f "..upstream_file)
end




-- ####################### server #######################

-- 根据server名字获取文件名
function _M.get_server_file(server_name, protocol)
    if protocol == "http" or protocol == "https" then
        return dynamic_http_servers_dir.."/"..server_name..".conf"
    else
        return dynamic_stream_servers_dir.."/"..server_name..".conf"
    end
end

-- 根据server名字获取证书文件名
function _M.get_cert_filename(server_name)
    return dynamic_certs_dir.."/"..server_name..".cert"
end

-- 根据server名字获取私钥文件名
function _M.get_key_filename(server_name)
    return dynamic_certs_dir.."/"..server_name..".key"
end


-- 定义http_server配置模版
_M.temp_http_server =
[[server {
    listen %s;
    server_name %s;
    %s
    location %s {
        proxy_pass http://%s;
    }
}]]

-- 定义http转https配置模版
_M.temp_http_to_https =
[[server {
    listen %s;
    server_name %s;
    return 301 https://$host$request_uri;
}]]

-- 定义https_server配置模版
_M.temp_tls_server =
[[server {
    listen %s;
    server_name %s;
    ssl_certificate %s;
    ssl_certificate_key %s;
    %s
    location %s {
        proxy_pass http://%s;
    }
}]]

-- 定义stream_server配置模版
_M.temp_stream_server =
[[server {
    listen %s;
    %s
    proxy_pass %s;
}]]

-- 保存server配置文件
function _M.server_save(data_table)
    local server_name = data_table.name
    local protocol = data_table.protocol
    -- 生成配置文件内容
    local options = ""
    for k, v in pairs(data_table.options) do
        if options == "" then
            options = string.format("%s %s;", k, v)
        else
            options = options .. string.format("    \n%s %s;", k, v)
        end
    end

    local content = ""
    if protocol == "https" then
        local cert = _M.get_cert_filename(server_name)
        local key = _M.get_key_filename(server_name)
        content = string.format(_M.temp_tls_server, data_table.port, data_table.domain, cert, key, options, data_table.path, data_table.upstream)
    elseif protocol == "http" then
        if data_table.transferHTTP then
            content = string.format(_M.temp_http_to_https, data_table.port, data_table.domain)
        else
            content = string.format(_M.temp_http_server, data_table.port, data_table.domain, options, data_table.path, data_table.upstream)
        end
    else
        content = string.format(_M.temp_stream_server, data_table.port, options, data_table.upstream)
    end

    -- 写入文件
    local file = io.open(_M.get_server_file(data_table.name, data_table.protocol), "w+")
    file:write(content)
    file.close()
end

-- 删除server配置文件
function _M.server_delete(server_name, protocol)
    local filename

    if protocol == "http" then
        filename = _M.get_server_file(server_name, protocol)
    elseif protocol == "https" then
        filename = _M.get_server_file(server_name, protocol)
        _M.certs_del(server_name)
    else
        filename = _M.get_server_file(server_name, protocol)
    end

    utils.shell("rm -f "..filename.."; echo $?", "0")
end

-- 如果该server对应的证书已存在，则返回true
function _M.certs_is_exists(server_name)
    local is_exists = true
    local r1 = utils.shell(string.format("ls %s | grep '^%s.cert$'", dynamic_certs_dir, server_name))
    local r2 = utils.shell(string.format("ls %s | grep '^%s.key$'", dynamic_certs_dir, server_name))

    if r1 == "0" and r2 == "0" then
        is_exists = false
    end

    return is_exists
end

-- 将证书和私钥的文件内容保存为文件
function _M.certs_save(server_name, cert_content, key_content)
    utils.shell(string.format("echo -n '%s' > %s/%s.cert", cert_content, dynamic_certs_dir, server_name))
    utils.shell(string.format("echo -n '%s' > %s/%s.key", key_content, dynamic_certs_dir, server_name))
end

-- 删除server对应的证书和私钥
function _M.certs_del(server_name)
    utils.shell(string.format("/bin/rm -f %s/%s.cert", dynamic_certs_dir, server_name))
    utils.shell(string.format("/bin/rm -f %s/%s.key", dynamic_certs_dir, server_name))
end



return _M