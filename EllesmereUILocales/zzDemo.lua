-- Temporary file that makes the locale guard report every locale check.
local L = EllesmereUI.RegisterLocale("deDE")
if not L then return end

L["Hello %s"] = "Hallo %s %s"
L["Hi %s %s"] = "Hallo %s"
L["Ready %s"] = "Bereit %1$s"
L["Repeat me"] = "Erste"
L["Repeat me"] = "Zweite"
L["Blank"] = ""
L["Same"] = "Same"
L["|cffff0000Red|r"] = "|cffff0000Rot"
L["  Padded  "] = "Gepolstert"
L["Tight"] = "  Locker  "
L["Line\nBreak"] = "Zeile"
L["Fähigkeit"] = "Fertigkeit"
