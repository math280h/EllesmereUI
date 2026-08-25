-- The registry of the checks. One entry declares everything about a check, and
-- a new check needs no other file.
--
-- scope decides when the guard calls a finding new. split() in guard.lua reads
-- it:
--   line   the change touched the line of the finding
--   file   the change touched the file (a whole-file finding has no line)
--   change the change caused the finding, at any line
--
-- sarif.lua puts summary in shortDescription, help in help, and both in
-- fullDescription. summary names the fault, and help says what to do.
local M = {}

M.ERROR, M.WARN, M.INFO = "error", "warn", "info"

M.CHECKS = {
    S1 = {
        scope = "line",
        name = "UnwrappedString",
        level = M.WARN,
        summary = "Text does not use EllesmereUI.L().",
        help = "Please use EllesmereUI.L() instead for text that should be "
            .. "translatable.",
    },
    S3 = {
        scope = "line",
        name = "UnstableKey",
        level = M.WARN,
        summary = "Text is joined with a variable.",
        help = "Please keep the sentence in one piece and use "
            .. "EllesmereUI.Lf() with a %s for the variable.",
    },
    S4 = {
        scope = "change",
        name = "RenamedSourceString",
        level = M.WARN,
        summary = "The English text changed, and the locale files keep the "
            .. "old text.",
        help = "Please change the left side in each EllesmereUILocales file, "
            .. "or put the original English text back.",
    },
    L1 = {
        scope = "line",
        name = "TranslatedKey",
        level = M.WARN,
        summary = "The left side is not English.",
        help = "Please put the English text on the left and your translation "
            .. "on the right.",
    },
    L2 = {
        scope = "line",
        name = "MissingFormatArgument",
        level = M.ERROR,
        summary = "The translation has more %s or %d places than the English "
            .. "text.",
        help = "Please remove the extra place, or number the places to match "
            .. "the English text.",
    },
    L2b = {
        scope = "line",
        name = "ExtraFormatArgument",
        level = M.INFO,
        summary = "The translation has fewer %s or %d places than the English "
            .. "text.",
        help = "Please check that this is deliberate. It is frequently "
            .. "correct and needs no change.",
    },
    L3 = {
        scope = "line",
        name = "FormatArgumentOrder",
        level = M.WARN,
        summary = "The numbered places do not match the English text.",
        help = "Please make the numbers match the English text.",
    },
    L4 = {
        scope = "line",
        name = "DuplicateKey",
        level = M.WARN,
        summary = "The same key appears two times.",
        help = "Please remove one of the two entries.",
    },
    L5 = {
        scope = "line",
        name = "EmptyTranslation",
        level = M.ERROR,
        summary = "The translation is empty.",
        help = "Please remove the entry, or set the value to true to show "
            .. "English.",
    },
    L7 = {
        scope = "file",
        name = "LocaleRegistrationMismatch",
        level = M.ERROR,
        summary = "RegisterLocale() does not match the file name.",
        help = "Please give the file name to RegisterLocale(). A file with no "
            .. "call gives no translations, and a call with another code "
            .. "sends the entries to that locale.",
    },
    L8 = {
        scope = "file",
        name = "LocaleFileUnreadable",
        level = M.ERROR,
        summary = "Lua cannot load the file.",
        help = "Please remove the byte order mark, and correct the syntax "
            .. "error. The guard checks no key after the error.",
    },
    L9 = {
        scope = "line",
        name = "UntranslatedValue",
        level = M.INFO,
        summary = "The translation is the same as the English text.",
        help = "Please translate the value, or set it to true to keep English "
            .. "on purpose.",
    },
    L10 = {
        scope = "line",
        name = "UnbalancedColorCode",
        level = M.ERROR,
        summary = "The |c and |r color codes do not match.",
        help = "Please add an |r for each |c.",
    },
    L11 = {
        scope = "line",
        name = "DroppedWhitespace",
        level = M.WARN,
        summary = "The translation drops spaces that the English text has.",
        help = "Please keep the spaces that the English text has.",
    },
    L11b = {
        scope = "line",
        name = "AddedWhitespace",
        level = M.INFO,
        summary = "The translation adds spaces that the English text does not "
            .. "have.",
        help = "Please check that this is deliberate. French, for example, "
            .. "uses a space before some punctuation marks.",
    },
    L12 = {
        scope = "line",
        name = "LineBreakCount",
        level = M.INFO,
        summary = "The translation has a different number of line breaks.",
        help = "Please look at this text in the game.",
    },
}

return M
