# Locale guard

Finds the translation defects that a change introduces and reports them as
GitHub code scanning alerts. The report shows only the lines that the change
touched. The guard does not report an existing problem in a different part of
a file until someone edits that part.

## Running it

```sh
lua5.1 .tools/locale/guard.lua --all                            # audit the whole tree
lua5.1 .tools/locale/guard.lua --base origin/main --worktree    # your uncommitted edits
lua5.1 .tools/locale/guard.lua --keys EllesmereUILocales/_keys.txt
lua5.1 .tools/locale/tests.lua                                  # self-test
```

| Flag | Meaning |
| --- | --- |
| `--all` | Report everything and ignore scoping. |
| `--base <ref>` | Scope the report to what changed against `<ref>`. Uses `<ref>...HEAD`. |
| `--worktree` | With `--base`, scope to uncommitted edits instead of commits. |
| `--sarif <file>` | Write SARIF 2.1.0 for `upload-sarif`. Always covers the whole tree. |
| `--sarif-min <sev>` | Lowest severity to put in the SARIF file. Defaults to `warn`. |
| `--keys <file>` | Write the translator key list. See [The key list](#the-key-list). |
| `--fail-on <sev>` | Exit 1 when an introduced finding reaches `error` or `warn`. |
| `--quiet` | Write no report and no progress messages. |

The guard writes the report to stdout. It fails only if you give `--fail-on`.
It writes all of the output files before it applies that check, thus a finding
cannot prevent the SARIF file.

The exit codes are `0` for a correct run, `1` for a finding that `--fail-on`
matched, and `2` if the guard cannot run.

## Checks

| ID | Severity | Fires when |
| --- | --- | --- |
| `S1` | warn | A literal reaches `:SetText()` without passing through `EllesmereUI.L()`. Nobody can translate it. |
| `S3` | warn | `L()` receives a concatenation involving something that is not a literal, so the key is not knowable. Adjacent literals joined by `..` are fine and are stitched back into one key. |
| `S4` | warn | An English source string changed or was removed while locale files still key on the old wording. Those entries now fall back to English silently. |
| `L1` | warn | The key contains translated text and matches no source string. Usually a rendered composite captured as a key: translate the value, not the key. |
| `L2` | error | The translation needs more format arguments than the English key supplies. `string.format` raises. |
| `L2b` | note | The translation uses fewer arguments than the key. Lua discards the extras, so this is often deliberate. |
| `L3` | warn | Positional specifiers differ from the key, so argument order is not preserved. |
| `L4` | warn | The same key is assigned twice in one file. The later value wins. |
| `L5` | error | The translation is `""`. `L()` returns it, so the label renders blank, which is worse than the English fallback. |
| `L7` | error | `RegisterLocale()` disagrees with the file name, or is missing. The whole file is inert. |
| `L8` | error | The file has a UTF-8 BOM, or failed to load. Keys below a load failure go unchecked. |
| `L9` | note | The value equals the key. Use `= true` to keep English on purpose. |
| `L10` | error | `\|c` and `\|r` are unbalanced in the translation but balanced in the key. The color applies to the text that renders after it. |
| `L11` | warn | The translation drops leading or trailing whitespace the key carries. That whitespace is layout. |
| `L11b` | note | The translation adds whitespace the key does not have. Sometimes deliberate; French wants a space before some punctuation. |
| `L12` | note | The line-break count differs from the key. |

Each check declares in `rules.lua` what it is anchored to — the line, the whole
file, or the change itself — so a new check cannot be added without saying when
it should fire.

New translatable keys are not a finding. They are listed as a paste-ready
`L["..."] = ""` block for translators.

## How keys are found

Two sources, because most of the addon's user-facing text never appears next to
an `L()` call:

- `EllesmereUI.L("...")` and `EllesmereUI.Lf("...")`.
- Literals in config fields the shared builders translate as they render:
  `text`, `label`, `tooltip`, `disabledTooltip`, `title`, `placeholder`,
  `buttonText`, `message`, `disclaimer`, `scaleWarning`, `checkbox`,
  `confirmText`, `cancelText`. The list lives in `source.lua`; leave a field off
  it and the guard goes quiet about everything behind that field.

A table marked `_noLoc = true` is skipped, matching the widget builders. The
language picker uses it so a player who booted the wrong locale can still read
the list.

Keys assembled at runtime from variables cannot be seen statically and are not
in the inventory. That is expected, and is why no check reports a locale key
merely for being absent from it.

## The key list

`guard.lua --keys` writes `EllesmereUILocales/_keys.txt`, the offline list for
translators. `locale-guard.yml` fails if the committed file is not current.
Write the file again with this command:

```sh
lua5.1 .tools/locale/guard.lua --keys EllesmereUILocales/_keys.txt
```

The list uses the same scan as the checks. Thus it contains the literals in
the config fields that the widget builders translate. These literals are most
of the options UI.

Each line is an `L["key"] = ""` assignment and not only a key. This format is
the same as the output of `/euiloc dump`. It is also necessary, because some
keys contain a newline or a quotation mark. A list of keys alone cannot show
these characters correctly.

A static scan cannot find the keys that the addon makes from variables. The
list does not contain them. Use `/euiloc` in the game to find them.
