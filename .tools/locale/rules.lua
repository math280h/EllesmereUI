-- The registry of the checks.
--
-- scope decides when the guard calls a finding new:
--   line   the change touched the line of the finding
--   file   the change touched the file (a whole-file finding has no line)
--   change the change caused the finding, at any line
--
-- sarif.lua puts summary in shortDescription, help in help, and both in
-- fullDescription.
local M = {}

M.ERROR, M.WARN, M.INFO = "error", "warn", "info"

M.CHECKS = {
    S1 = {
        scope = "line",
        name = "UnwrappedString",
        level = M.WARN,
        summary = "The code sends a literal to :SetText() and does not use "
            .. "EllesmereUI.L().",
        help = "You cannot translate this string. Use "
            .. "obj:SetText(EllesmereUI.L(\"...\")).",
    },
    S3 = {
        scope = "line",
        name = "UnstableKey",
        level = M.WARN,
        summary = "EllesmereUI.L() receives a concatenation with a value that "
            .. "is not a literal.",
        help = "The scan cannot find the key, thus no locale file can contain "
            .. "it. Use EllesmereUI.Lf() with format arguments. As an "
            .. "alternative, put the full sentence in one literal.",
    },
    S4 = {
        scope = "change",
        name = "RenamedSourceString",
        level = M.WARN,
        summary = "Someone changed or deleted an English source string, but "
            .. "the locale files keep the old text.",
        help = "The addon shows English for these entries. Change the key in "
            .. "each EllesmereUILocales/*.lua file. As an alternative, put "
            .. "back the original text.",
    },
    L1 = {
        scope = "line",
        name = "TranslatedKey",
        level = M.WARN,
        summary = "The key contains translated text and matches no source "
            .. "string.",
        help = "This occurs when you use a composed string as a key. Use the "
            .. "English string as the key. Then translate the value.",
    },
    L2 = {
        scope = "line",
        name = "MissingFormatArgument",
        level = M.ERROR,
        summary = "The translation needs more format arguments than the "
            .. "English key supplies.",
        help = "string.format makes an error when the addon runs. Remove the "
            .. "extra specifier. As an alternative, use positional specifiers "
            .. "that agree with the key.",
    },
    L2b = {
        scope = "line",
        name = "ExtraFormatArgument",
        level = M.INFO,
        summary = "The translation uses fewer format arguments than the "
            .. "English key supplies.",
        help = "Lua removes the extra arguments. This is frequently correct. "
            .. "If it is correct, do nothing.",
    },
    L3 = {
        scope = "line",
        name = "FormatArgumentOrder",
        level = M.WARN,
        summary = "The positional specifiers do not agree with the English "
            .. "key.",
        help = "The order of the arguments changes, thus the values go to the "
            .. "wrong positions. Change the numbers of the %n$ specifiers to "
            .. "agree with the key.",
    },
    L4 = {
        scope = "line",
        name = "DuplicateKey",
        level = M.WARN,
        summary = "A locale file gives a value to the same key two times.",
        help = "Lua keeps the second value, and the first translation does "
            .. "not load. Remove one of the two entries.",
    },
    L5 = {
        scope = "line",
        name = "EmptyTranslation",
        level = M.ERROR,
        summary = "The translation is an empty string.",
        help = "L() returns the empty string, thus the label shows no text. "
            .. "Remove the entry. As an alternative, set the value to true to "
            .. "show English.",
    },
    L7 = {
        scope = "file",
        name = "LocaleRegistrationMismatch",
        level = M.ERROR,
        summary = "RegisterLocale() does not agree with the file name, or the "
            .. "file does not call it.",
        help = "The addon loads no translation from this file. Give the file "
            .. "name to RegisterLocale().",
    },
    L8 = {
        scope = "file",
        name = "LocaleFileUnreadable",
        level = M.ERROR,
        summary = "The file has a UTF-8 byte order mark, or Lua cannot load "
            .. "it.",
        help = "The guard does not check the keys after the error. Remove the "
            .. "byte order mark. Then correct the syntax error.",
    },
    L9 = {
        scope = "line",
        name = "UntranslatedValue",
        level = M.INFO,
        summary = "The translation is the same as the English key.",
        help = "Translate the value. As an alternative, set the value to true "
            .. "to show English.",
    },
    L10 = {
        scope = "line",
        name = "UnbalancedColorCode",
        level = M.ERROR,
        summary = "The translation has a different number of |c and |r codes "
            .. "than the English key.",
        help = "The color continues into the text after this string. Add an "
            .. "|r for each |c.",
    },
    L11 = {
        scope = "line",
        name = "DroppedWhitespace",
        level = M.WARN,
        summary = "The English key has space characters at the start or the "
            .. "end, but the translation does not.",
        help = "These space characters keep the string away from the adjacent "
            .. "text. Keep them.",
    },
    L11b = {
        scope = "line",
        name = "AddedWhitespace",
        level = M.INFO,
        summary = "The translation has space characters that the English key "
            .. "does not have.",
        help = "This is sometimes correct. For example, French uses a space "
            .. "before some punctuation marks.",
    },
    L12 = {
        scope = "line",
        name = "LineBreakCount",
        level = M.INFO,
        summary = "The translation has a different number of line breaks than "
            .. "the English key.",
        help = "The string can be too large for its frame. Examine it in the "
            .. "game.",
    },
}

return M
