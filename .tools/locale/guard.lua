#!/usr/bin/env lua5.1
-- Locale guard. Reports translation defects introduced by a change.
--
--   lua5.1 .tools/locale/guard.lua --all
--   lua5.1 .tools/locale/guard.lua --base origin/main --worktree
--   lua5.1 .tools/locale/guard.lua --base <sha> --sarif results.sarif --fail-on error
--   lua5.1 .tools/locale/guard.lua --keys EllesmereUILocales/_keys.txt
local here = arg[0]:match("^(.*)[/\\][^/\\]*$") or "."
package.path = here .. "/?.lua;" .. package.path

local source = require("source")
local catalog = require("catalog")
local checks = require("checks")
local diff = require("diff")
local keys = require("keys")
local sarif = require("sarif")

local LOCALES = "EllesmereUILocales"
local TOOL = {
    name = "EllesmereUI locale guard",
    uri = "https://github.com/EllesmereGaming/EllesmereUI/blob/main/.tools/locale/README.md",
}
local ORDER = { [checks.ERROR] = 1, [checks.WARN] = 2, [checks.INFO] = 3 }

local function sh(cmd)
    local p = io.popen(cmd)
    if not p then return nil end
    local s = p:read("*a")
    p:close()
    return s
end

local function git(root, rest)
    return sh(string.format('git -C "%s" %s', root, rest))
end

local function lines(s)
    local t = {}
    for l in (s or ""):gmatch("[^\r\n]+") do t[#t + 1] = l end
    return t
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function isLocale(path)
    return path:match("^" .. LOCALES .. "/[^/]+%.lua$") ~= nil
end

-- The addon files that the key inventory reads. scanBase() and scanHead() must
-- use the same rule, or S4 reports the difference as removed keys.
local function isSource(path)
    return path:match("%.lua$") ~= nil and not isLocale(path)
        and not path:match("^Libs/") and not path:match("^%.tools/")
end

local function scanHead(root, files)
    local scan = source.new()
    for _, path in ipairs(files) do
        if isSource(path) then
            local src = readFile(root .. "/" .. path)
            if src then source.scanFile(scan, path, src) end
        end
    end
    return scan
end

-- A file that the change does not touch has the same bytes on both sides, thus
-- the scan reads it from disk. "git show" runs only for the changed files.
local function scanBase(root, base, range)
    local scan = source.new()
    -- ls-tree takes no glob pathspec, thus it lists the whole tree and
    -- isSource() below does the filtering.
    local listed = lines(git(root, "ls-tree -r --name-only " .. base))
    if #listed == 0 then
        io.stderr:write("the base ", base, " lists no file. S4 and the new "
            .. "key list are not available.\n")
        return nil
    end

    local changed = {}
    for _, path in ipairs(lines(git(root, string.format(
        'diff --name-only %s -- "*.lua"', range)))) do
        changed[path] = true
    end

    for _, path in ipairs(listed) do
        if isSource(path) then
            local src
            if changed[path] then
                src = git(root, string.format('show %s:"%s"', base, path))
            else
                src = readFile(root .. "/" .. path)
            end
            if src and #src > 0 then source.scanFile(scan, path, src) end
        end
    end
    return scan
end

local function loadCatalogs(root, files)
    local out = {}
    for _, path in ipairs(files) do
        if isLocale(path) then
            local code = path:match("([^/]+)%.lua$")
            out[#out + 1] = catalog.load(root .. "/" .. path, code)
            out[#out].path = path
        end
    end
    return out
end

local function touchedLines(root, range)
    return diff.parse(git(root, string.format(
        'diff --unified=0 %s -- "*.lua"', range)))
end

local function sortFindings(t)
    table.sort(t, function(a, b)
        if ORDER[a.severity] ~= ORDER[b.severity] then
            return ORDER[a.severity] < ORDER[b.severity]
        end
        if a.path ~= b.path then return a.path < b.path end
        return a.line < b.line
    end)
end

local function split(findings, touched)
    if not touched then return findings, {} end
    local new, pre = {}, {}
    for _, f in ipairs(findings) do
        local t = touched[f.path]
        local hit
        if f.scope == "line" then
            hit = t ~= nil and t[f.line] == true
        elseif f.scope == "file" then
            hit = t ~= nil and next(t) ~= nil
        else
            hit = true
        end
        if hit then new[#new + 1] = f else pre[#pre + 1] = f end
    end
    return new, pre
end

local function escapeCell(s)
    return (s:gsub("|", "\\|"))
end

local function loc(f)
    return f.line > 0 and (f.path .. ":" .. f.line) or f.path
end

local function render(new, pre, newKeys)
    local o = { "### Locale guard", "" }
    if #new == 0 then
        o[#o + 1] = "This change introduced no translation problems."
    else
        local errors, warns, infos = 0, 0, 0
        for _, f in ipairs(new) do
            if f.severity == checks.ERROR then errors = errors + 1
            elseif f.severity == checks.WARN then warns = warns + 1
            else infos = infos + 1 end
        end
        o[#o + 1] = string.format("%d error, %d warning, %d note (introduced by "
            .. "this change).", errors, warns, infos)
        o[#o + 1] = ""
        o[#o + 1] = "| Severity | Check | Location | Detail |"
        o[#o + 1] = "| --- | --- | --- | --- |"
        for _, f in ipairs(new) do
            o[#o + 1] = string.format("| %s | %s | `%s` | %s |", f.severity,
                f.check, loc(f), escapeCell(f.message))
        end
    end

    if #newKeys > 0 then
        o[#o + 1] = ""
        o[#o + 1] = string.format("<details><summary>%d new translatable key(s)"
            .. "</summary>", #newKeys)
        o[#o + 1] = ""
        o[#o + 1] = "Copy these into `EllesmereUILocales/<code>.lua` and "
            .. "translate the right side. If you made this change, you must "
            .. "only write `EllesmereUILocales/_keys.txt` again."
        o[#o + 1] = ""
        o[#o + 1] = "```lua"
        for _, k in ipairs(newKeys) do
            o[#o + 1] = keys.entry(k)
        end
        o[#o + 1] = "```"
        o[#o + 1] = ""
        o[#o + 1] = "</details>"
    end

    if #pre > 0 then
        o[#o + 1] = ""
        o[#o + 1] = string.format("<details><summary>%d pre-existing issue(s) "
            .. "outside this change</summary>", #pre)
        o[#o + 1] = ""
        for _, f in ipairs(pre) do
            o[#o + 1] = string.format("- `%s` %s %s", loc(f), f.check, f.message)
        end
        o[#o + 1] = ""
        o[#o + 1] = "</details>"
    end

    o[#o + 1] = ""
    return table.concat(o, "\n")
end

local function writeFile(path, body)
    local f = assert(io.open(path, "wb"))
    f:write(body)
    f:close()
end

local function main()
    local opts = {}
    local i = 1
    while i <= #arg do
        local a = arg[i]
        if a == "--all" then opts.all = true
        elseif a == "--base" then i = i + 1; opts.base = arg[i]
        elseif a == "--worktree" then opts.worktree = true
        elseif a == "--fail-on" then i = i + 1; opts.failOn = arg[i]
        elseif a == "--sarif" then i = i + 1; opts.sarif = arg[i]
        elseif a == "--sarif-min" then i = i + 1; opts.sarifMin = arg[i]
        elseif a == "--keys" then i = i + 1; opts.keys = arg[i]
        elseif a == "--quiet" then opts.quiet = true
        else
            io.stderr:write("this argument is not known: ", a, "\n")
            os.exit(2)
        end
        i = i + 1
    end

    for _, k in ipairs({ "sarifMin", "failOn" }) do
        local v = opts[k]
        if v and v ~= checks.ERROR and v ~= checks.WARN and v ~= checks.INFO then
            io.stderr:write("the severity must be error, warn or info: ", v, "\n")
            os.exit(2)
        end
    end

    local root = (git(".", "rev-parse --show-toplevel") or ""):gsub("%s+$", "")
    if root == "" then
        io.stderr:write("not a git repository\n")
        os.exit(2)
    end

    local files = {}
    for _, path in ipairs(lines(git(root, "ls-files"))) do
        if isSource(path) or isLocale(path) then files[#files + 1] = path end
    end

    local scan = scanHead(root, files)
    local catalogs = loadCatalogs(root, files)
    local base = not opts.all and opts.base
    -- Three dots start the range at the merge base. --worktree drops the
    -- endpoint, thus the range also covers the edits that are not committed.
    local range = base and (opts.worktree and base or (base .. "...HEAD"))
    local baseScanned = base and scanBase(root, base, range)

    local findings, newKeys = checks.run(scan, catalogs, baseScanned)
    sortFindings(findings)

    local touched = range and touchedLines(root, range)
    local new, pre = split(findings, touched)

    if opts.keys then
        local body, n = keys.render(scan)
        writeFile(opts.keys, body)
        if not opts.quiet then
            io.stderr:write(string.format("wrote %d keys to %s\n", n, opts.keys))
        end
    end

    -- sarif.render receives every finding, not only the new ones.
    if opts.sarif then
        local body, n = sarif.render(findings, opts.sarifMin, TOOL)
        writeFile(opts.sarif, body)
        if not opts.quiet then
            io.stderr:write(string.format("wrote %d results to %s\n", n, opts.sarif))
        end
    end

    if not opts.quiet then io.write(render(new, pre, newKeys), "\n") end

    if opts.failOn then
        for _, f in ipairs(new) do
            if f.severity == opts.failOn
                or (opts.failOn == checks.WARN and f.severity == checks.ERROR) then
                os.exit(1)
            end
        end
    end
end

main()
