-- Temporary file that makes the locale guard report S1 and S3.
local frame = CreateFrame("Frame")
local name = UnitName("player")

frame.fs = frame:CreateFontString(nil, "OVERLAY")
frame.fs:SetText("This string never reaches a translator.")

local function greet()
    return EllesmereUI.L("Welcome back, " .. name)
end

return greet
