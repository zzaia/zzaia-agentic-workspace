-- Enriches each log record with the container_name by reading Docker's
-- config.v2.json from the mounted /var/lib/docker/containers path.
-- Results are cached per container_id to avoid repeated file I/O.

local container_cache = {}

function add_container_meta(tag, timestamp, record)
    local container_id = tag:match("^docker%.(.+)$")
    if not container_id then
        return 0, timestamp, record
    end

    if container_cache[container_id] == nil then
        local path = "/var/lib/docker/containers/" .. container_id .. "/config.v2.json"
        local f = io.open(path, "r")
        if f then
            local content = f:read("*a")
            f:close()
            local name = content:match('"Name"%s*:%s*"(/[^"]+)"')
            container_cache[container_id] = name or ("/" .. container_id:sub(1, 12))
        else
            container_cache[container_id] = "/" .. container_id:sub(1, 12)
        end
    end

    record["container_name"] = container_cache[container_id]
    return 1, timestamp, record
end
