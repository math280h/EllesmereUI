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
        summary = "This text goes to the screen with no translation step.",
        help = "Give the text to EllesmereUI.L() before SetText() receives "
            .. "it. Then a locale file can replace it.",
    },
    S3 = {
        scope = "line",
        name = "UnstableKey",
        level = M.WARN,
        summary = "Part of this text comes from a variable, thus nobody can "
            .. "translate it.",
        help = "The finished sentence exists only while the game runs, and a "
            .. "locale file cannot list it. Keep the sentence in one piece "
            .. "and put the variable in a %s with EllesmereUI.Lf().",
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
        summary = "The left side is already in another language, and the "
            .. "addon never asks for it.",
        help = "The left side must be the English text that the addon shows. "
            .. "Put the English on the left and your translation on the right.",
    },
    L2 = {
        scope = "line",
        name = "MissingFormatArgument",
        level = M.ERROR,
        summary = "The translation uses more %s or %d places than the "
            .. "English text gives it.",
        help = "The addon stops with an error when it shows this line. "
            .. "Remove the extra place, or number the places to match the "
            .. "English text.",
    },
    L2b = {
        scope = "line",
        name = "ExtraFormatArgument",
        level = M.INFO,
        summary = "The translation uses fewer %s or %d places than the "
            .. "English text gives it.",
        help = "The values that no place uses do not appear. This is "
            .. "frequently correct. If it is correct, do nothing.",
    },
    L3 = {
        scope = "line",
        name = "FormatArgumentOrder",
        level = M.WARN,
        summary = "The numbered places such as %1$s do not match the "
            .. "English text.",
        help = "Each number chooses which value goes in that place. A wrong "
            .. "number puts the wrong value in the sentence. Make the "
            .. "numbers match the English text.",
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
        help = "A file with no call gives no translation. A call with another "
            .. "code puts the entries under that locale, thus the wrong "
            .. "players read them. Give the file name to RegisterLocale().",
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
