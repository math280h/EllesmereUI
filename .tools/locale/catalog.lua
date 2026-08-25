-- Loads a locale file in a sandbox and collects its entries.
local M = {}

local function compile(src, name, env)
    if setfenv then
        local chunk, err = loadstring(src, name)
        if not chunk then return nil, err end
        setfenv(chunk, env)
        return chunk
    end
    return load(src, name, "t", env)
end

function M.load(path, code)
    local cat = { code = code, path = path, entries = {}, duplicates = {},
        declared = nil, bom = false, err = nil, keys = {} }

    local f = io.open(path, "rb")
    if not f then
        cat.err = "cannot open file"
        return cat
    end
    local data = f:read("*a")
    f:close()

    cat.bom = data:sub(1, 3) == "\239\187\191"
    local src = cat.bom and data:sub(4) or data

    local seen = {}
    local env
    -- env is the global table of the chunk. The chunk calls RegisterLocale,
    -- which returns L, then assigns each of its keys to L. L stores no value,
    -- thus __newindex receives every assignment, and a duplicate key causes a
    -- second call.
    local L = setmetatable({}, { __newindex = function(_, k, v)
        local line = debug.getinfo(2, "l").currentline
        if seen[k] then
            cat.duplicates[#cat.duplicates + 1] = { key = k, first = seen[k],
                line = line }
        else
            seen[k] = line
        end
        cat.entries[#cat.entries + 1] = { key = k, value = v, line = line }
        cat.keys[k] = true
    end })

    env = {
        EllesmereUI = { RegisterLocale = function(c) cat.declared = c; return L end },
        GetLocale = function() return code end,
        string = string, table = table, math = math, type = type, pairs = pairs,
        ipairs = ipairs, tostring = tostring, tonumber = tonumber, select = select,
    }

    local chunk, err = compile(src, "@" .. path, env)
    if not chunk then
        cat.err = err
        return cat
    end
    local ok, rerr = pcall(chunk)
    if not ok then cat.err = rerr end
    return cat
end

return M
