-- Writes the offline key list for translators. Each line is an entry that a
-- translator copies into a locale file.
local M = {}

-- The escapes for a key. string.format("%q") is not usable here, because it
-- writes a newline as a backslash and a line break, and some keys contain a
-- newline.
local QUOTE = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n",
    ["\r"] = "\\r", ["\t"] = "\\t" }

function M.quote(s)
    local body = s:gsub('[%z\1-\31\\"]', function(c)
        return QUOTE[c] or string.format("\\%d", c:byte())
    end)
    return '"' .. body .. '"'
end

function M.entry(k)
    return string.format("L[%s] = \"\"", M.quote(k))
end

-- The list comes from the same scan as the checks. It thus contains the config
-- field literals and the EllesmereUI.L() arguments.
function M.render(scan)
    local list = {}
    -- An empty config field is a key, but it has no text to translate.
    for k in pairs(scan.keys) do
        if k ~= "" then list[#list + 1] = k end
    end
    table.sort(list)

    local o = {
        "-- The guard.lua --keys command makes this file. Do not edit it manually.",
        string.format("-- It contains each English key that the addon gives as "
            .. "a literal (%d keys).", #list),
        "-- Copy the keys that you must translate into EllesmereUILocales/<code>.lua.",
        "-- Then write the translation on the right side of each line.",
        "-- The addon makes some keys from variables. This file does not contain",
        "-- them. Use the /euiloc command in the game to find them.",
    }
    for _, k in ipairs(list) do
        o[#o + 1] = M.entry(k)
    end
    o[#o + 1] = ""
    return table.concat(o, "\n"), #list
end

return M
