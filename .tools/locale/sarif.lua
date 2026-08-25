-- SARIF 2.1.0 output for github/codeql-action/upload-sarif.
--
-- It writes no partialFingerprints. The action calculates them from the source
-- files.
local rules = require("rules")

local M = {}

local LEVEL = { error = "error", warn = "warning", info = "note" }
local RANK = { error = 1, warn = 2, info = 3 }

local ESCAPES = {
    ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

-- The function changes only these characters. The other bytes stay the same,
-- thus the message stays correct UTF-8.
local function esc(s)
    return (s:gsub('[%z\1-\31\\"]', function(c)
        return ESCAPES[c] or string.format("\\u%04x", c:byte())
    end))
end

local function str(s)
    return '"' .. esc(s) .. '"'
end

local function rule(id)
    local r = rules.CHECKS[id]
        or error("check " .. id .. " is not in rules.CHECKS")
    return table.concat({
        '{"id":', str(id), ',"name":', str(r.name),
        ',"shortDescription":{"text":', str(r.summary), "}",
        ',"fullDescription":{"text":', str(r.summary .. " " .. r.help), "}",
        ',"help":{"text":', str(r.help), ',"markdown":', str(r.help), "}",
        ',"defaultConfiguration":{"level":', str(LEVEL[r.level]), "}",
        ',"properties":{"tags":["localization"],"problem.severity":',
        str(LEVEL[r.level]), "}}",
    })
end

-- S4 carries line 0, because it describes a file and not a line. Code scanning
-- shows no alert without a region, thus the result uses line 1.
local function result(f, index)
    return table.concat({
        '{"ruleId":', str(f.check), ',"ruleIndex":', tostring(index),
        ',"level":', str(LEVEL[f.severity]),
        ',"message":{"text":', str(f.message), "}",
        ',"locations":[{"physicalLocation":{"artifactLocation":{"uri":',
        str(f.path), '},"region":{"startLine":',
        tostring(f.line > 0 and f.line or 1), "}}}]}",
    })
end

function M.render(findings, min, tool)
    local keep = {}
    for _, f in ipairs(findings) do
        if RANK[f.severity] <= RANK[min or "warn"] then keep[#keep + 1] = f end
    end

    local ids, seen = {}, {}
    for _, f in ipairs(keep) do
        if not seen[f.check] then
            seen[f.check] = true
            ids[#ids + 1] = f.check
        end
    end
    table.sort(ids)

    local index, rules = {}, {}
    for i, id in ipairs(ids) do
        index[id] = i - 1
        rules[#rules + 1] = rule(id)
    end

    local results = {}
    for _, f in ipairs(keep) do
        results[#results + 1] = result(f, index[f.check])
    end

    return table.concat({
        '{"$schema":"https://json.schemastore.org/sarif-2.1.0.json"',
        ',"version":"2.1.0","runs":[{"tool":{"driver":{"name":',
        str(tool.name), ',"informationUri":', str(tool.uri),
        ',"rules":[', table.concat(rules, ","), "]}}",
        ',"results":[', table.concat(results, ","), "]}]}",
    }), #keep
end

return M
