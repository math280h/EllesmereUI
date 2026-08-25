-- Scans the addon source for the keys and the strings that no L() call wraps.
local lexer = require("lexer")
local gsub, find = string.gsub, string.find

local M = {}

-- A widget builder gives these config fields to EllesmereUI.L() when it draws.
-- A literal in one of them is thus a key, and the source needs no L() call.
-- The scan reads no other field name. See EllesmereUI_Widgets.lua.
M.FIELDS = {
    text = true, label = true, tooltip = true, disabledTooltip = true,
    title = true, placeholder = true, buttonText = true, message = true,
    disclaimer = true, scaleWarning = true, checkbox = true,
    confirmText = true, cancelText = true,
}

-- A table that must stay English contains _noLoc, for example the language
-- picker in EUI__General_Options.lua. The scan reads no literal in that table.
local NOLOC = "_noLoc"

local function isProse(s)
    local t = gsub(gsub(s, "|c%x%x%x%x%x%x%x%x", ""), "|r", "")
    return find(t, "%a") ~= nil
end

-- The three lists of a scan. keys holds each key and its first position.
-- unwrapped holds a prose literal that :SetText() receives with no L() call.
-- concat holds an L() argument that ".." builds from a part that is not a
-- literal.
function M.new()
    return { keys = {}, unwrapped = {}, concat = {} }
end

function M.scanFile(scan, path, src)
    local t = lexer.tokens(src)
    -- braces is the depth of the open table constructors. noLoc[d] becomes
    -- true when the scan reads _noLoc at depth d.
    local braces, noLoc = 0, {}
    for i = 1, #t do
        local tok = t[i]
        if tok.kind == "punc" and tok.value == "{" then
            braces = braces + 1
            noLoc[braces] = false
        elseif tok.kind == "punc" and tok.value == "}" then
            noLoc[braces] = nil
            braces = braces > 0 and braces - 1 or 0
        elseif tok.kind == "name" and tok.value == NOLOC and braces > 0 then
            noLoc[braces] = true
        end

        if tok.kind == "name" and tok.value == "EllesmereUI" and t[i + 4]
            and t[i + 1].value == "." and (t[i + 2].value == "L" or t[i + 2].value == "Lf")
            and t[i + 3].value == "(" and t[i + 4].kind == "str" then
            -- The argument can be adjacent literals that ".." joins. The loop
            -- joins them into one key. A part that is not a literal makes the
            -- key unstable, and scan.concat receives it.
            local first, key, j, unstable = t[i + 4], t[i + 4].value, i + 4, false
            while t[j + 1] and t[j + 1].value == ".." do
                if t[j + 2] and t[j + 2].kind == "str" then
                    key = key .. t[j + 2].value
                    j = j + 2
                else
                    unstable = true
                    break
                end
            end
            if unstable then
                scan.concat[#scan.concat + 1] = { path = path, line = first.line,
                    text = key }
            elseif not scan.keys[key] then
                scan.keys[key] = { path = path, line = first.line }
            end
        elseif tok.kind == "name" and M.FIELDS[tok.value] and t[i + 2]
            and t[i + 1].value == "=" and t[i + 2].kind == "str" then
            local marked = false
            for d = 1, braces do
                if noLoc[d] then marked = true; break end
            end
            local k = t[i + 2]
            if not marked and not scan.keys[k.value] then
                scan.keys[k.value] = { path = path, line = k.line }
            end
        elseif tok.kind == "punc" and tok.value == ":" and t[i + 3]
            and t[i + 1].value == "SetText" and t[i + 2].value == "("
            and t[i + 3].kind == "str" and isProse(t[i + 3].value) then
            scan.unwrapped[#scan.unwrapped + 1] = { path = path,
                line = t[i + 3].line, text = t[i + 3].value }
        end
    end
end

return M
