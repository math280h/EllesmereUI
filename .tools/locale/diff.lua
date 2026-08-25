-- Parses "git diff --unified=0". M.parse gives map[path][line] = true for each
-- line that the diff adds.
local M = {}

function M.parse(text)
    local map, cur = {}, nil
    for line in (text or ""):gmatch("[^\r\n]+") do
        local path = line:match("^%+%+%+ b/(.+)$")
        if path then
            cur = path
            map[cur] = map[cur] or {}
        elseif line:match("^%+%+%+ ") then
            cur = nil
        elseif cur then
            local start, count = line:match("^@@ %-%d+,?%d* %+(%d+),?(%d*) @@")
            if start then
                local s = tonumber(start)
                -- No count means one line. A count of 0 means the hunk only
                -- deletes.
                local c = count == "" and 1 or tonumber(count)
                for i = s, s + c - 1 do map[cur][i] = true end
            end
        end
    end
    return map
end

return M
