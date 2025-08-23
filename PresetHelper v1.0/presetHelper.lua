-- Symphony of the Night - PresetHelper v0.1
-- Crazy4blades
-- Load presets from external file
local presets = dofile("preset_definitions.lua")

-- Config
local timeoutFrames = 60 * 17
local startFrame = nil
local baseX = 10
local baseY = 40
local spacing = 14
local fontColor = 0xFFCCCCCC
local shadowColor = 0xFF000000
local gothicFont = "Verdana"
local previousStage = nil
local selectedPreset = nil
local stage45DetectedFrame = nil
local presetDetectionDelay = 60 -- frames (1 second at 60fps)

-- Memory addresses
local menuStageAddress = 0x974A0
local presetNameAddress = 0x1A78E4

-- Draw shadowed text
function drawHint(text, x, y)
    gui.drawText(x + 1, y + 1, text, shadowColor, nil, gothicFont)
    gui.drawText(x, y, text, fontColor, nil, gothicFont)
end

-- Auto-detect preset name from memory
function detectPresetName()
    local maxChars = 12
    local offset = 0
    local chars = {}
    local foundNonSpace = false

    local firstChar = memory.read_u8(presetNameAddress)
    local secondChar = memory.read_u8(presetNameAddress + 1)

    if firstChar == string.byte("D") and secondChar == string.byte(" ") then
        offset = 2
    end

    for i = 0, maxChars - 1 do
        local addr = presetNameAddress + offset + i
        local byte = memory.read_u8(addr)
        if byte == 0x00 then
            break
        end
        -- Skip leading spaces
        if not foundNonSpace and byte == string.byte(" ") then
            goto continue
        end
        foundNonSpace = true
        table.insert(chars, string.char(byte))
        ::continue::
    end

    local result = table.concat(chars)

    -- Remove everything after the first space
    local spaceIndex = result:find(" ")
    if spaceIndex then
        result = result:sub(1, spaceIndex - 1)
    end

    -- Normalize preset name
    result = result:gsub("[%z\1-\31\127]", "") -- remove ASCII control chars
    :gsub("\194[\128-\191]", " ") -- common UTF‑8 NBSP (0xC2 0xA0) and similar
    :gsub("\129", " ") -- handle stray 0x81 byte
    :gsub("^%s*(.-)%s*$", "%1") -- trim
    :gsub("%s*|%s*", "-"):gsub("%s*'%s*", "-"):gsub("%s+", "-"):gsub("^%-+", ""):gsub("%-+$", "")

    for name, _ in pairs(presets) do
        if result == name then
            return name
        end
    end

    return nil
end

-- Main render function
function renderHints()
    local stage = memory.readbyte(menuStageAddress)
    local currentFrame = emu.framecount()

    -- Detect preset only when stage transitions to 0x45
    if previousStage ~= 0x45 and stage == 0x45 then
        local name = detectPresetName()
        if name then
            selectedPreset = name
            print(string.format("Preset detected: %s", selectedPreset))
        end
    end
    previousStage = stage

    -- Display hints when stage is 0x41
    local isInStage = (stage == 0x41)
    if isInStage and selectedPreset then
        if not startFrame then
            startFrame = currentFrame
        end

        local remainingFrames = timeoutFrames - (currentFrame - startFrame)
        if remainingFrames <= 0 then
            gui.clearGraphics()
            selectedPreset = nil
            startFrame = nil
            return
        end

        local hintSet = presets[selectedPreset]
        if not hintSet then
            return
        end

        -- Draw preset hints
        for i, hint in ipairs(hintSet) do
            drawHint(hint, baseX, baseY + (i - 1) * spacing)
        end

        -- Draw signature below all hints
        local signatureY = 200
        drawHint("PresetHelper v0.1 by CRAZY4BLADES", baseX, signatureY)
    else
        gui.clearGraphics()
        startFrame = nil
    end
end
-- Hook into BizHawk frame end
event.onframeend(renderHints, "Draw Preset Hints When In Menu")
