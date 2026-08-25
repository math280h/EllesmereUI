local rules = require("rules")
local find, sub, match, gsub, gmatch = string.find, string.sub, string.match,
    string.gsub, string.gmatch

local M = {}

M.ERROR, M.WARN, M.INFO = rules.ERROR, rules.WARN, rules.INFO

-- The conversion characters of string.format. eachSpec() reads a "%" run as a
-- specifier only when the letter that ends it is in this set, thus "%y" is
-- text and "%d" is not.
local CONV = "diouxXeEfgGqcsaA"

-- The non-ASCII characters that an English key can contain. foreign() removes
-- them, then it finds the other non-ASCII bytes. The escapes are UTF-8 bytes,
-- because this file stays ASCII.
local ALLOW = {
    "\194\160",     -- U+00A0 no-break space
    "\194\176",     -- U+00B0 degree sign
    "\194\183",     -- U+00B7 middle dot
    "\195\151",     -- U+00D7 multiplication sign
    "\226\128\147", -- U+2013 en dash
    "\226\128\148", -- U+2014 em dash
    "\226\128\152", -- U+2018 left single quotation mark
    "\226\128\153", -- U+2019 right single quotation mark
    "\226\128\156", -- U+201C left double quotation mark
    "\226\128\157", -- U+201D right double quotation mark
    "\226\128\162", -- U+2022 bullet
    "\226\128\166", -- U+2026 horizontal ellipsis
    "\226\134\146", -- U+2192 rightwards arrow
}

-- Calls fn for each string.format specifier in s. fn receives the conversion
-- character, and the number of a %n$ specifier or nil for a plain one. A "%%"
-- pair is an escaped percent sign and gives no call.
local function eachSpec(s, fn)
    local i, n = 1, #s
    while i <= n do
        local a = find(s, "%", i, true)
        if not a then return end
        if sub(s, a + 1, a + 1) == "%" then
            i = a + 2
        else
            local pos, conv = match(s, "^%%(%d+)%$(%a)", a)
            if pos and find(CONV, conv, 1, true) then
                fn(conv, pos)
                i = a + #pos + 3
            else
                local flags, c = match(s, "^%%([-+#0-9.]*)(%a)", a)
                if c and find(CONV, c, 1, true) then
                    fn(c, nil)
                    i = a + #flags + 2
                else
                    i = a + 1
                end
            end
        end
    end
end

local function specCounts(s)
    local t = {}
    eachSpec(s, function(c) t[c] = (t[c] or 0) + 1 end)
    return t
end

local function positions(s)
    local t = {}
    eachSpec(s, function(_, p) if p then t[p] = true end end)
    return t
end

-- Compares the counts, not only which conversions occur. Three %s is not
-- two %s.
local function sameCounts(a, b)
    for k, v in pairs(a) do if b[k] ~= v then return false end end
    for k, v in pairs(b) do if a[k] ~= v then return false end end
    return true
end

local function countPat(s, pat)
    local n = 0
    for _ in gmatch(s, pat) do n = n + 1 end
    return n
end

-- Returns true when the string closes each |c color code with an |r. It counts
-- the two, thus it does not check the order.
local function balanced(s)
    return countPat(s, "|c%x%x%x%x%x%x%x%x") == countPat(s, "|r")
end

-- Returns true when s holds a non-ASCII byte that ALLOW does not list. L1 reads
-- this to find a key that someone already translated.
local function foreign(s)
    -- Most keys are ASCII. The loop below makes one string copy for each
    -- allowed sequence, thus this test comes first.
    if not find(s, "[\128-\255]") then return false end
    local t = s
    for i = 1, #ALLOW do t = gsub(t, ALLOW[i], "") end
    return find(t, "[\128-\255]") ~= nil
end

-- Shortens a key for a finding message. The message goes in a Markdown table
-- cell, thus a newline becomes the two characters "\n". A key above 90
-- bytes ends with "...", and the cut moves back to the start of a UTF-8
-- character, because Lua counts bytes.
local function short(s)
    local n = 90
    s = gsub(s, "\n", "\\n")
    if #s <= n then return s end
    local cut = n
    while cut > 0 do
        local b = sub(s, cut + 1, cut + 1):byte()
        if not b or b < 128 or b >= 192 then break end
        cut = cut - 1
    end
    return sub(s, 1, cut) .. "..."
end

M.short = short

-- Appends one finding to out. rules.CHECKS gives the scope, thus no call site
-- repeats it.
local function add(out, path, line, check, severity, message)
    local r = rules.CHECKS[check]
        or error("check " .. check .. " is not in rules.CHECKS")
    out[#out + 1] = { path = path, line = line, check = check,
        severity = severity, message = message, scope = r.scope }
end

-- Adds the findings that the source scan gives: S1 for a literal that no L()
-- call wraps, and S3 for an L() argument that ".." builds from a value that is
-- not a literal.
function M.source(out, scan)
    for _, u in ipairs(scan.unwrapped) do
        add(out, u.path, u.line, "S1", M.WARN,
            "String does not pass through EllesmereUI.L() and cannot be "
            .. "translated: " .. short(u.text))
    end
    for _, c in ipairs(scan.concat) do
        add(out, c.path, c.line, "S3", M.WARN,
            "EllesmereUI.L() receives a concatenated expression, so the key is "
            .. "not stable: " .. short(c.text))
    end
end

-- Adds S4 for each English key that the change removed from the source while a
-- locale file still holds a translation for it. A run with no base scan has
-- nothing to compare and adds nothing.
function M.rename(out, baseScan, scan, catalogs)
    if not baseScan then return end
    local removed = {}
    for k, origin in pairs(baseScan.keys) do
        if not scan.keys[k] then removed[#removed + 1] = { key = k, origin = origin } end
    end
    table.sort(removed, function(a, b) return a.key < b.key end)
    for _, r in ipairs(removed) do
        local holders = {}
        for _, cat in ipairs(catalogs) do
            if cat.keys[r.key] then holders[#holders + 1] = cat.code end
        end
        if #holders > 0 then
            add(out, r.origin.path, 0, "S4", M.WARN,
                "English source string changed or removed; " .. #holders
                .. " locale(s) still key on the old text and now fall back to "
                .. "English (" .. table.concat(holders, ", ") .. "): "
                .. short(r.key))
        end
    end
end

function M.catalog(out, cat, sourceKeys)
    -- A chunk that stops at an error keeps the entries before that point. The
    -- checks below run on them.
    if cat.err then
        add(out, cat.path, 1, "L8", M.ERROR, "File failed to load, so any key "
            .. "below the failure is unchecked: " .. short(tostring(cat.err)))
    end
    if cat.bom then
        add(out, cat.path, 1, "L8", M.ERROR,
            "File begins with a UTF-8 BOM and must be saved without one.")
    end
    if not cat.declared and not cat.err then
        add(out, cat.path, 1, "L7", M.ERROR,
            "No EllesmereUI.RegisterLocale() call found.")
    elseif cat.declared and cat.declared ~= cat.code then
        add(out, cat.path, 1, "L7", M.ERROR,
            "RegisterLocale(\"" .. cat.declared .. "\") does not match the file "
            .. "name, so the whole file is inert.")
    end

    for _, d in ipairs(cat.duplicates) do
        add(out, cat.path, d.line, "L4", M.WARN,
            "Duplicate key first defined on line " .. d.first
            .. "; the later value wins: " .. short(d.key))
    end

    -- The checks that compare one translation with its English key. A value of
    -- true means the locale keeps English on purpose, thus only a string value
    -- reaches them.
    for _, e in ipairs(cat.entries) do
        if type(e.value) == "string" then
            if e.value == "" then
                add(out, cat.path, e.line, "L5", M.ERROR,
                    "Empty translation renders as blank text; remove the entry "
                    .. "or use = true to keep English: " .. short(e.key))
            else
                local sk, sv = specCounts(e.key), specCounts(e.value)
                local over = false
                for c, n in pairs(sv) do
                    if n > (sk[c] or 0) then over = true end
                end
                if over then
                    add(out, cat.path, e.line, "L2", M.ERROR,
                        "Translation needs more format arguments than the English "
                        .. "key supplies; string.format will raise: " .. short(e.key))
                elseif not sameCounts(sk, sv) then
                    add(out, cat.path, e.line, "L2b", M.INFO,
                        "Translation uses fewer format arguments than the English "
                        .. "key; the extras are ignored: " .. short(e.key))
                end

                if not sameCounts(positions(e.key), positions(e.value)) then
                    add(out, cat.path, e.line, "L3", M.WARN,
                        "Positional specifiers differ from the English key, so "
                        .. "argument order is not preserved: " .. short(e.key))
                end

                if find(e.key, "|", 1, true)
                    and balanced(e.key) and not balanced(e.value) then
                    add(out, cat.path, e.line, "L10", M.ERROR,
                        "Unbalanced |c and |r color escapes; the color applies "
                        .. "to the text that renders after this string: "
                        .. short(e.key))
                end

                local kl, kt = match(e.key, "^%s*"), match(e.key, "%s*$")
                local vl, vt = match(e.value, "^%s*"), match(e.value, "%s*$")
                if kl ~= vl or kt ~= vt then
                    if (#kl > 0 and #vl == 0) or (#kt > 0 and #vt == 0) then
                        add(out, cat.path, e.line, "L11", M.WARN,
                            "Translation drops leading or trailing whitespace the "
                            .. "English key uses for layout: " .. short(e.key))
                    else
                        add(out, cat.path, e.line, "L11b", M.INFO,
                            "Translation adds leading or trailing whitespace the "
                            .. "English key does not have: " .. short(e.key))
                    end
                end

                if countPat(e.value, "\n") ~= countPat(e.key, "\n") then
                    add(out, cat.path, e.line, "L12", M.INFO,
                        "Line-break count differs from the English key: "
                        .. short(e.key))
                end

                if e.value == e.key then
                    add(out, cat.path, e.line, "L9", M.INFO,
                        "Translation equals the key; use = true to keep English "
                        .. "on purpose: " .. short(e.key))
                end

                if not sourceKeys[e.key] and foreign(e.key) then
                    add(out, cat.path, e.line, "L1", M.WARN,
                        "Key contains translated text and matches no source "
                        .. "string; translate the value, not the key: "
                        .. short(e.key))
                end
            end
        end
    end

end

function M.run(scan, catalogs, baseScan)
    local out = {}
    M.source(out, scan)
    M.rename(out, baseScan, scan, catalogs)
    for _, cat in ipairs(catalogs) do
        M.catalog(out, cat, scan.keys)
    end
    local newKeys = {}
    if baseScan then
        for k in pairs(scan.keys) do
            if not baseScan.keys[k] then newKeys[#newKeys + 1] = k end
        end
        table.sort(newKeys)
    end
    return out, newKeys
end

return M
