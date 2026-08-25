-- Tokenizes the addon source for the scan. It gives a token for each string,
-- name and punctuation mark, and it ignores the comments and the numbers.
-- unescape() resolves the escapes, thus a key here is equal to the key that a
-- locale file makes.
local sub, find, match, rep, gsub = string.sub, string.find, string.match,
    string.rep, string.gsub

local M = {}

-- The escapes that unescape() resolves. The last entry is a backslash before
-- a real line break, which Lua reads as a newline in the string.
local ESC = { a = "\a", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
    v = "\v", ["\\"] = "\\", ['"'] = '"', ["'"] = "'", ["\n"] = "\n" }

-- Reads a long bracket that opens at i, for example "[[" or "[==[". It returns
-- the number of "=" signs and the index of the first content byte, or nil.
local function longBracket(s, i)
    if sub(s, i, i) ~= "[" then return nil end
    local j = i + 1
    while sub(s, j, j) == "=" do j = j + 1 end
    if sub(s, j, j) == "[" then return j - i - 1, j + 1 end
    return nil
end

-- Finds the long bracket that closes a level. It returns the index of the "]"
-- and the index after the bracket. An unterminated bracket gives the end of
-- the string for both, thus the scan stops.
local function longEnd(s, start, level)
    local a, b = find(s, "]" .. rep("=", level) .. "]", start, true)
    if not a then return #s + 1, #s + 1 end
    return a, b + 1
end

-- Resolves the escapes of a quoted string. It reads \ddd as decimal and \xHH
-- as hexadecimal. An escape that Lua does not know gives the character
-- itself, thus a malformed escape does not stop the scan.
local function unescape(raw)
    if not find(raw, "\\", 1, true) then return raw end
    local out, i, n = {}, 1, #raw
    while i <= n do
        local c = sub(raw, i, i)
        if c ~= "\\" then
            out[#out + 1] = c
            i = i + 1
        else
            i = i + 1
            local e = sub(raw, i, i)
            if ESC[e] then
                out[#out + 1] = ESC[e]
                i = i + 1
            elseif e == "x" then
                local h = match(raw, "^%x%x", i + 1)
                if h then
                    out[#out + 1] = string.char(tonumber(h, 16))
                    i = i + 3
                else
                    out[#out + 1] = e
                    i = i + 1
                end
            elseif match(e, "%d") then
                local d = match(raw, "^%d%d?%d?", i)
                out[#out + 1] = string.char(tonumber(d) % 256)
                i = i + #d
            else
                out[#out + 1] = e
                i = i + 1
            end
        end
    end
    return table.concat(out)
end

function M.tokens(src)
    local out, i, n, line = {}, 1, #src, 1
    -- Moves i to "to" and adds the line breaks of the span that it passes,
    -- thus a token after a multi-line comment or string keeps the right line.
    local function advance(from, to)
        local _, c = gsub(sub(src, from, to - 1), "\n", "")
        line = line + c
        i = to
    end

    while i <= n do
        local c = sub(src, i, i)
        if c == "\n" then
            line = line + 1
            i = i + 1
        elseif c == " " or c == "\t" or c == "\r" then
            i = i + 1
        elseif sub(src, i, i + 1) == "--" then
            local level, start = longBracket(src, i + 2)
            if level then
                local _, after = longEnd(src, start, level)
                advance(i, after)
            else
                local j = find(src, "\n", i, true)
                advance(i, j or (n + 1))
            end
        elseif c == '"' or c == "'" then
            -- A backslash hides the byte after it, thus an escaped quote does
            -- not end the string. A line break ends the scan, because Lua
            -- does not allow one inside a quoted string.
            local j = i + 1
            while j <= n do
                local d = sub(src, j, j)
                if d == "\\" then
                    j = j + 2
                elseif d == c or d == "\n" then
                    break
                else
                    j = j + 1
                end
            end
            out[#out + 1] = { kind = "str", value = unescape(sub(src, i + 1, j - 1)),
                line = line }
            advance(i, sub(src, j, j) == c and j + 1 or j)
        else
            local level, start = longBracket(src, i)
            if level then
                local e, after = longEnd(src, start, level)
                out[#out + 1] = { kind = "str", value = sub(src, start, e - 1),
                    line = line }
                advance(i, after)
            else
                -- A name gives a token, and a number gives none. The scan
                -- reads a number as one unit, thus "0x1F" does not become a
                -- name.
                local w = match(src, "^[%a_][%w_]*", i)
                local num = not w and (match(src, "^0[xX]%x*", i)
                    or match(src, "^%d+%.?%d*", i) or match(src, "^%.%d+", i))
                if w then
                    out[#out + 1] = { kind = "name", value = w, line = line }
                    i = i + #w
                elseif num then
                    i = i + #num
                elseif sub(src, i, i + 1) == ".." then
                    out[#out + 1] = { kind = "punc", value = "..", line = line }
                    i = i + 2
                else
                    out[#out + 1] = { kind = "punc", value = c, line = line }
                    i = i + 1
                end
            end
        end
    end
    return out
end

return M
