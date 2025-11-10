local UI = {}

function UI.drawWorldGenWindow(engine, screenW, screenH)
    local SLAB = require("lib.vendor.slab")

    if engine.showWorldGenWindow then
        SLAB.BeginWindow('WorldGenWindow', {
            Title = "World Manager",
            X = screenW/2 - 200,
            Y = screenH/2 - 120,
            W = 400,
            H = 240,
            AutoSizeWindow = false,
            Border = 20
        })

        SLAB.Text("Current Seed: " .. (engine.gameData.worldSeed or 0))
        SLAB.Separator()
        SLAB.Text("New Seed:")

        if SLAB.Input('SeedInput', {Text = engine.seedInputText}) then
            engine.seedInputText = SLAB.GetInputText()
        end

        if SLAB.Button('Randomize') then
            engine.seedInputText = tostring(engine.generateRandomSeed())
            engine.statusText = "Randomized: " .. engine.seedInputText
        end

        SLAB.Separator()

        -- Clear World button
        if SLAB.Button('Clear World') then
            engine.clearWorld()
            engine.statusText = "World cleared - no generation until complete"
            print("Clear World button clicked")
        end

        SLAB.Separator()

        -- Generate button (will apply seed AND clear)
        if SLAB.Button('Generate New World') then
            engine.applyNewSeed(engine.seedInputText)
        end

        SLAB.SameLine()

        if SLAB.Button('Cancel') then
            engine.showWorldGenWindow = false
        end

        SLAB.EndWindow()
    end
end

function UI.drawMenuBar(engine)
    local SLAB = require("lib.vendor.slab")

    if SLAB.BeginMainMenuBar() then
        if SLAB.BeginMenu("File") then
            if SLAB.MenuItem("World Manager") then
                engine.showWorldGenWindow = true
                engine.seedInputText = tostring(engine.gameData.worldSeed or engine.generateRandomSeed())
            end
            SLAB.EndMenu()
        end
        SLAB.EndMainMenuBar()
    end
end

return UI