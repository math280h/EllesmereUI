#!/usr/bin/env lua5.1
-- Self-test. Each check has a case that must fire and a case that must not.
--
--   lua5.1 .tools/locale/tests.lua
local here = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path

local lexer = require("lexer")
local catalog = require("catalog")
local source = require("source")
local checks = require("checks")
local rules = require("rules")

local failed, total = 0, 0

local function ok(name, cond, detail)
    total = total + 1
    if not cond then
        failed = failed + 1
        io.write("FAIL  ", name, detail and ("  (" .. tostring(detail) .. ")") or "", "\n")
    end
end

local function tmpwrite(body)
    local path = os.tmpname()
    -- On Windows, os.tmpname gives a name at the drive root, for example
    -- "\s3ff.", which is not writable. Add the temp directory. On Linux the
    -- name is already a full path.
    if package.config:sub(1, 1) == "\\" then
        local dir = os.getenv("TEMP") or os.getenv("TMP") or "."
        path = dir .. "\\" .. path:gsub("^[\\/]+", "")
    end
    if not path:match("%.lua$") then path = path .. ".lua" end
    local f = assert(io.open(path, "wb"))
    f:write(body)
    f:close()
    return path
end

local function findingsFor(body, code)
    local path = tmpwrite(body)
    local cat = catalog.load(path, code or "deDE")
    cat.path = code or "deDE"
    os.remove(path)
    return cat
end

local function has(list, id)
    for _, f in ipairs(list) do if f.check == id then return true, f end end
    return false
end

local function catalogChecks(body, sourceKeys, code)
    local cat = findingsFor(body, code)
    local out = {}
    checks.catalog(out, cat, sourceKeys or {})
    return out, cat
end

local HEAD = 'local L = EllesmereUI.RegisterLocale("deDE")\nif not L then return end\n'

-- lexer ---------------------------------------------------------------------
do
    local t = lexer.tokens('-- EllesmereUI.L("ghost")\nlocal a = "real"\n')
    local strings = {}
    for _, tok in ipairs(t) do
        if tok.kind == "str" then strings[#strings + 1] = tok.value end
    end
    ok("lexer ignores comment text", #strings == 1 and strings[1] == "real",
        table.concat(strings, ","))

    t = lexer.tokens('--[[ EllesmereUI.L("ghost") ]]\nlocal a = "real"\n')
    local n = 0
    for _, tok in ipairs(t) do if tok.kind == "str" then n = n + 1 end end
    ok("lexer ignores long comments", n == 1, n)

    t = lexer.tokens('local a = "say \\"hi\\" now"\n')
    ok("lexer resolves escapes", t[4] and t[4].value == 'say "hi" now',
        t[4] and t[4].value)

    t = lexer.tokens('local a = "line one"\nlocal b = "line two"\n')
    ok("lexer tracks line numbers", t[4].line == 1 and t[8].line == 2,
        t[8] and t[8].line)
end

-- source scan ---------------------------------------------------------------
do
    local scan = source.new()
    source.scanFile(scan, "x.lua", 'EllesmereUI.L("Enable")\n')
    ok("source picks up direct L()", scan.keys["Enable"] ~= nil)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'local c = { text = "Sort Bags" }\n')
    ok("source picks up declarative field", scan.keys["Sort Bags"] ~= nil)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'label:SetText("Sort Bags")\n')
    ok("source flags unwrapped SetText", #scan.unwrapped == 1)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'label:SetText(EllesmereUI.L("Sort Bags"))\n')
    ok("source ignores wrapped SetText", #scan.unwrapped == 0)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'label:SetText("42")\n')
    ok("source ignores non-prose SetText", #scan.unwrapped == 0)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'local c = { label = "Combat Alert" }\n')
    ok("source picks up label", scan.keys["Combat Alert"] ~= nil)

    scan = source.new()
    source.scanFile(scan, "x.lua",
        'local v = { _noLoc = true, ["esES"] = { text = "Espanol" } }\n')
    ok("source skips a _noLoc table", scan.keys["Espanol"] == nil)

    scan = source.new()
    source.scanFile(scan, "x.lua",
        'local a = { _noLoc = true, text = "Skip" }\nlocal b = { text = "Take" }\n')
    ok("_noLoc does not leak past its table",
        scan.keys["Skip"] == nil and scan.keys["Take"] ~= nil)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'EllesmereUI.L("Prefix " .. name)\n')
    ok("source flags a key concatenated with a variable", #scan.concat == 1)

    scan = source.new()
    source.scanFile(scan, "x.lua", 'EllesmereUI.L("Add an action"\n .. "\\nThen drop it.")\n')
    ok("source joins adjacent literals into one key",
        scan.keys["Add an action\nThen drop it."] ~= nil)
    ok("source does not flag a literal-only concatenation", #scan.concat == 0)
end

-- catalog load --------------------------------------------------------------
do
    local cat = findingsFor(HEAD .. 'L["A"] = "Ay"\nL["B"] = true\n')
    ok("catalog loads entries", #cat.entries == 2, #cat.entries)
    ok("catalog keeps the true sentinel", cat.entries[2].value == true)
    ok("catalog records line numbers", cat.entries[1].line == 3,
        cat.entries[1].line)
    ok("catalog reads the declared code", cat.declared == "deDE", cat.declared)

    cat = findingsFor(HEAD .. 'L["A"] = "one"\nL["A"] = "two"\n')
    ok("catalog sees duplicates", #cat.duplicates == 1, #cat.duplicates)
    ok("catalog points at the first definition",
        cat.duplicates[1] and cat.duplicates[1].first == 3)
end

-- checks --------------------------------------------------------------------
do
    local out = catalogChecks(HEAD .. 'L["You have %d of %s"] = "Du hast %d von %s und %s"\n')
    ok("L2 fires when the translation wants more arguments", has(out, "L2"))

    out = catalogChecks(HEAD .. 'L["You have %d of %s"] = "Du hast %d"\n')
    ok("L2b notes fewer arguments", has(out, "L2b"))
    ok("L2 stays quiet on fewer arguments", not has(out, "L2"))

    out = catalogChecks(HEAD .. 'L["Set to 100% to disable"] = "Auf 100% setzen"\n')
    ok("literal percent is not a specifier", not has(out, "L2") and not has(out, "L2b"))

    out = catalogChecks(HEAD .. 'L["%1$s Slot"] = "%s Platz"\n')
    ok("L3 fires on dropped positional", has(out, "L3"))

    out = catalogChecks(HEAD .. 'L["%1$s of %2$s"] = "%2$s von %1$s"\n')
    ok("L3 allows reordering", not has(out, "L3"))

    out = catalogChecks(HEAD .. 'L["Open Talents"] = ""\n')
    ok("L5 fires on empty translation", has(out, "L5"))

    out = catalogChecks(HEAD .. 'L["|cff00ff00Ready|r"] = "|cff00ff00Bereit"\n')
    ok("L10 fires on unbalanced color", has(out, "L10"))

    out = catalogChecks(HEAD .. 'L["|cff00ff00Ready|r"] = "|cff00ff00Bereit|r"\n')
    ok("L10 allows balanced color", not has(out, "L10"))

    out = catalogChecks(HEAD .. 'L["    Enemy Units"] = "Feindliche Einheiten"\n')
    ok("L11 fires on dropped indentation", has(out, "L11"))

    out = catalogChecks(HEAD .. 'L["    Enemy Units"] = "    Feindliche Einheiten"\n')
    ok("L11 allows preserved indentation", not has(out, "L11"))

    out = catalogChecks(HEAD .. 'L["Death Recap"] = " Recapitulatif"\n')
    ok("added whitespace is only a note", has(out, "L11b") and not has(out, "L11"))

    out = catalogChecks(HEAD .. 'L["Enable"] = "Enable"\n')
    ok("L9 notes an untranslated copy", has(out, "L9"))

    out = catalogChecks(HEAD .. 'L["\236\157\180 Only applies"] = "x"\n')
    ok("L1 fires on a translated key", has(out, "L1"))

    out = catalogChecks(HEAD .. 'L["\236\157\180 Only applies"] = "x"\n',
        { ["\236\157\180 Only applies"] = { path = "a.lua", line = 1 } })
    ok("L1 defers to a real source string", not has(out, "L1"))

    out = catalogChecks(HEAD .. 'L["Tyrannical \194\183 Bargain"] = "x"\n')
    ok("L1 allows typographic characters", not has(out, "L1"))

    local cat = findingsFor(HEAD .. 'L["A"] = "Ay"\n', "frFR")
    local o = {}
    checks.catalog(o, cat, {})
    ok("L7 fires when the code does not match the file", has(o, "L7"))
end

-- rename ---------------------------------------------------------------------
do
    local baseScan = source.new()
    source.scanFile(baseScan, "x.lua", 'EllesmereUI.L("Enable")\n')
    local headScan = source.new()
    source.scanFile(headScan, "x.lua", 'EllesmereUI.L("Enabled")\n')
    local cat = findingsFor(HEAD .. 'L["Enable"] = "Aktivieren"\n')
    cat.path = "deDE.lua"

    local out = {}
    checks.rename(out, baseScan, headScan, { cat })
    ok("S4 fires when a rename orphans a translation", has(out, "S4"))

    out = {}
    checks.rename(out, baseScan, baseScan, { cat })
    ok("S4 stays quiet when nothing changed", not has(out, "S4"))
end

-- check registries -----------------------------------------------------------
do
    -- add() refuses a check that has no scope. Each finding must carry one of
    -- the three scopes that split() reads.
    local out = {}
    local cat = findingsFor(HEAD .. 'L["A"] = ""\n')
    checks.catalog(out, cat, {})
    local scoped = true
    for _, f in ipairs(out) do
        if f.scope ~= "line" and f.scope ~= "file" and f.scope ~= "change" then
            scoped = false
        end
    end
    ok("every emitted finding carries a known scope", scoped)

    local fine = pcall(checks.source, {}, { unwrapped = {}, concat = {} })
    ok("the source checks emit cleanly", fine)

    -- One entry declares every field of a check, and both value sets are
    -- closed.
    local SCOPES = { line = true, file = true, change = true }
    local LEVELS = { [checks.ERROR] = true, [checks.WARN] = true,
        [checks.INFO] = true }
    local bad = {}
    for id, r in pairs(rules.CHECKS) do
        if not r.name or not r.summary or not r.help
            or not LEVELS[r.level] or not SCOPES[r.scope] then
            bad[#bad + 1] = id
        end
    end
    ok("every check declares a complete rule", #bad == 0,
        table.concat(bad, ","))
end

-- truncation -----------------------------------------------------------------
do
    -- 60 Korean syllables of three bytes each. 90 bytes is exactly 30
    -- syllables, thus the cut needs no move.
    local korean = string.rep("\234\176\128", 60)
    local cut = checks.short(korean)
    local trimmed = cut:gsub("%.%.%.$", "")
    ok("truncation does not split a character", #trimmed % 3 == 0, #trimmed)

    local b = trimmed:byte(#trimmed)
    ok("truncation ends on a complete character", b == 128, b)
    ok("short leaves a string under the limit alone", checks.short("plain") == "plain")

    -- One ASCII byte before the syllables. 90 bytes now lands inside the 30th
    -- syllable, thus the cut moves back to byte 88.
    local mixed = "x" .. string.rep(string.char(234, 176, 128), 60)
    local mtrim = checks.short(mixed):gsub("%.%.%.$", "")
    ok("truncation moves back out of a split character", #mtrim == 88, #mtrim)
    ok("the moved cut ends on a complete character",
        mtrim:byte(#mtrim) == 128, mtrim:byte(#mtrim))
end

-- key list -------------------------------------------------------------------
do
    local keys = require("keys")

    ok("a newline becomes a two-character escape",
        keys.quote("a\nb") == '"a\\nb"', keys.quote("a\nb"))
    ok("a quote is escaped", keys.quote('say "hi"') == '"say \\"hi\\""',
        keys.quote('say "hi"'))
    ok("a backslash is escaped", keys.quote("a\\b") == '"a\\\\b"',
        keys.quote("a\\b"))
    ok("an entry stays on one line",
        select(2, keys.entry("a\nb"):gsub("\n", "")) == 0)
    ok("an entry is loadable Lua",
        loadstring("local L = {} " .. keys.entry('a\nb"c')) ~= nil)

    local body, n = keys.render({ keys = { ["b"] = true, ["a"] = true, [""] = true } })
    ok("the empty key is left out", n == 2, n)
    ok("keys are sorted", body:find('L["a"] = ""\nL["b"] = ""', 1, true) ~= nil)
    ok("the count in the header matches the list", body:find("(2 keys)", 1, true) ~= nil)
    ok("the list ends with a newline", body:sub(-1) == "\n")
end

-- SARIF ----------------------------------------------------------------------
do
    local sarif = require("sarif")
    local TOOL = { name = "t", uri = "u" }

    local function finding(check, severity, line, message)
        return { path = "a.lua", line = line, check = check,
            severity = severity, message = message or "m", scope = "line" }
    end

    local body, n = sarif.render({
        finding("L5", checks.ERROR, 3),
        finding("S1", checks.WARN, 4),
        finding("L9", checks.INFO, 5),
    }, checks.WARN, TOOL)
    ok("notes are left out below the threshold", n == 2, n)
    ok("an error keeps its level", body:find('"level":"error"', 1, true) ~= nil)
    ok("a warn becomes a SARIF warning",
        body:find('"level":"warning"', 1, true) ~= nil)
    ok("a filtered-out rule is not declared",
        body:find('"id":"L9"', 1, true) == nil)

    local all = select(2, sarif.render({
        finding("L9", checks.INFO, 5),
    }, checks.INFO, TOOL))
    ok("info passes its own threshold", all == 1, all)

    -- The rules are indexed by position. A mismatch gives every alert the
    -- wrong description.
    body = sarif.render({
        finding("S1", checks.WARN, 1),
        finding("L5", checks.ERROR, 2),
        finding("S1", checks.WARN, 3),
    }, checks.WARN, TOOL)
    local order = {}
    for id in body:gmatch('"id":"([^"]+)"') do order[#order + 1] = id end
    ok("rules are declared in sorted order",
        order[1] == "L5" and order[2] == "S1", table.concat(order, ","))
    local seen = {}
    for id, idx in body:gmatch('"ruleId":"([^"]+)","ruleIndex":(%d+)') do
        seen[id] = tonumber(idx)
    end
    ok("every result indexes its own rule", seen.L5 == 0 and seen.S1 == 1,
        tostring(seen.L5) .. "/" .. tostring(seen.S1))

    body = sarif.render({ finding("S1", checks.WARN, 1, 'a "q" and a \n break') },
        checks.WARN, TOOL)
    ok("a quote in a message is escaped",
        body:find('a \\"q\\" and a \\n break', 1, true) ~= nil)
    ok("no raw newline reaches the JSON",
        body:find("\n", 1, true) == nil)

    -- checks.lua gives line 0 to S4 only.
    body = sarif.render({ { path = "a.lua", line = 0, check = "S4",
        severity = checks.WARN, message = "m", scope = "change" } },
        checks.WARN, TOOL)
    ok("a finding with no line anchors to line 1",
        body:find('"startLine":1', 1, true) ~= nil)

    ok("a check with no rule is refused", not pcall(sarif.render,
        { finding("NOPE", checks.WARN, 1) }, checks.WARN, TOOL))
end

-- diff scoping ---------------------------------------------------------------
do
    local diff = require("diff")
    local m = diff.parse(table.concat({
        "diff --git a/a.lua b/a.lua",
        "--- a/a.lua",
        "+++ b/a.lua",
        "@@ -10,0 +11,3 @@",
        "@@ -40 +43 @@",
        "--- a/b.lua",
        "+++ b/b.lua",
        "@@ -5,2 +5,0 @@",
    }, "\n"))

    ok("added block is attributed", m["a.lua"][11] and m["a.lua"][12]
        and m["a.lua"][13])
    ok("untouched neighbours are not", not m["a.lua"][10] and not m["a.lua"][14])
    ok("a one-line hunk needs no count", m["a.lua"][43])
    ok("a pure deletion attributes nothing", next(m["b.lua"]) == nil)

    m = diff.parse("--- a/x.lua\n+++ /dev/null\n@@ -1,5 +0,0 @@\n")
    ok("a deleted file is skipped", m["x.lua"] == nil)
end

io.write(string.format("%d/%d passed\n", total - failed, total))
os.exit(failed == 0 and 0 or 1)
