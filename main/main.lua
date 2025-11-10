local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local Camera = require("lib.vendor.hump.camera")
local lfs = require("love.filesystem")
local Perlin = require("lib.modules.perlin")
local Input = require("lib.modules.input")
local UI = require("lib.modules.ui")

-- ==================== ENGINE TABLE & STATE ====================
local engine = {
    gameData = {},
    chunks = {},
    camera = nil,
    camX = 0, camY = 0,
    images = {},
    assetsDir = "dat/grid_assets/",
    perlin = nil,
    showWorldGenWindow = false,
    seedInputText = "",
    statusText = "",
    mouseDebug = ""
}

if not lfs.getInfo(engine.assetsDir) then
    print("Creating assets directory:", engine.assetsDir)
    lfs.createDirectory(engine.assetsDir)
end

local function getTerrainColor(noiseValue)
    local n = (noiseValue + 1) / 2
    if n < 0.3 then return 0.1, 0.3, 0.8
    elseif n < 0.4 then return 0.2, 0.5, 0.9
    elseif n < 0.5 then return 0.9, 0.8, 0.6
    elseif n < 0.7 then return 0.3, 0.7, 0.2
    elseif n < 0.85 then return 0.4, 0.5, 0.2
    else return 0.6, 0.6, 0.6
    end
end

-- World management
function engine.clearWorld()
    engine.images = {}
    local items = lfs.getDirectoryItems(engine.assetsDir)
    local count = 0
    for _, item in ipairs(items) do
        if item:match("^cell_%d+_%d+%.png$") then
            local success = lfs.remove(engine.assetsDir .. item)
            if success then count = count + 1 end
        end
    end
    engine.statusText = string.format("Cleared %d files", count)
    print(engine.statusText)
end

function engine.applyNewSeed(newSeed)
    local seed = tonumber(newSeed) or math.random(1, 999999)
    engine.gameData.worldSeed = seed
    engine.perlin = Perlin:new(seed)
    engine.clearWorld()
    engine.showWorldGenWindow = false
    engine.statusText = string.format("NEW SEED: %d", seed)
    print("Applied seed:", seed)
end

function engine.generateRandomSeed()
    return math.random(1, 999999)
end

-- Image generation
function engine.generateCellImage(i, j, size)
    print(string.format("Generating cell %d,%d...", i, j))
    local imgData = love.image.newImageData(size, size)

    for py = 0, size-1 do
        for px = 0, size-1 do
            local wx, wy = i * size + px, j * size + py
            local noise = engine.perlin:octaveNoise(wx, wy, 4, 0.5)
            local r, g, b = getTerrainColor(noise)
            imgData:setPixel(px, py, r, g, b, 1)
        end
    end

    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    local success = pcall(function() return imgData:encode("png", filename) end)
    if not success then print("Save failed") return nil end

    local img = love.graphics.newImage(imgData)
    engine.images[i] = engine.images[i] or {}
    engine.images[i][j] = img
    print(string.format("Saved cell %d,%d", i, j))
    return img
end

function engine.getCellImage(i, j, size)
    if not engine.images[i] then engine.images[i] = {} end
    if engine.images[i][j] then return engine.images[i][j] end

    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    if lfs.getInfo(filename) then
        local success, img = pcall(function() return love.graphics.newImage(filename) end)
        if success and img then
            engine.images[i][j] = img
            return img
        else
            lfs.remove(filename)
        end
    end
    return engine.generateCellImage(i, j, size)
end

function engine.init()
    engine.camera = Camera(0, 0)
    engine.camera.smoother = function() return 1 end
    engine.camera:zoom(1)

    local seed = engine.gameData.worldSeed or os.time()
    engine.perlin = Perlin:new(seed)
    engine.seedInputText = tostring(seed)
    engine.camSpeed = engine.gameData.camera.moveSpeed or 300
    engine.statusText = "Press F5 to open world generator"
    print("Engine initialized - Seed:", seed)
end

-- ==================== LOVE2D CALLBACKS ====================
function love.load(args)
    SLAB.Initialize(args)
    engine.gameData = JSON.decode(love.filesystem.read("dat/json/game.json"))

    love.window.setMode(engine.gameData.window.width, engine.gameData.window.height, {
        vsync = engine.gameData.window.vsync,
        resizable = engine.gameData.window.resizable
    })
    love.window.setFullscreen(engine.gameData.window.fullscreen, "desktop")
    engine.font = love.graphics.newFont("dat/fonts/ZenDots-Regular.ttf", 16)
    engine.fHeight = engine.font:getHeight()
    engine.init()
end

function love.update(dt)
    SLAB.Update(dt)

    local moveX, moveY = Input.getMovement()
    local len = math.sqrt(moveX * moveX + moveY * moveY)
    if len > 0 then
        moveX = moveX / len * engine.camSpeed * dt
        moveY = moveY / len * engine.camSpeed * dt
    end

    engine.camX = engine.camX + moveX
    engine.camY = engine.camY + moveY
    engine.camera:lookAt(engine.camX, engine.camY)
end

function love.draw()
    local size = engine.gameData.chunkSize or 256
    local screenW, screenH = love.graphics.getDimensions()
    local camX, camY = engine.camera:position()
    local viewLeft = camX - screenW/2
    local viewRight = camX + screenW/2
    local viewTop = camY - screenH/2
    local viewBottom = camY + screenH/2

    local gridStartX = math.floor(viewLeft / size) - 1
    local gridStartY = math.floor(viewTop / size) - 1
    local gridEndX = math.ceil(viewRight / size) + 1
    local gridEndY = math.ceil(viewBottom / size) + 1

    engine.camera:attach()
    for j = gridStartY, gridEndY do
        for i = gridStartX, gridEndX do
            local x, y = i * size, j * size
            if x + size < viewLeft or x > viewRight or
                    y + size < viewTop or y > viewBottom then
                goto continue
            end
            local img = engine.getCellImage(i, j, size)
            if img then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, x, y)
            end
            ::continue::
        end
    end
    engine.camera:detach()

    -- DEBUG VISUALIZATION
    love.graphics.setColor(1, 1, 0, 1)
    love.graphics.print(string.format("SEED: %d", engine.gameData.worldSeed or 0), 10, 10)
    love.graphics.print(string.format("CAM: (%.1f, %.1f)", engine.camX, engine.camY), 10, 30)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 50)
    love.graphics.print(engine.statusText, 10, 70)

    -- Show mouse position
    local mx, my = love.mouse.getPosition()
    love.graphics.print(string.format("MOUSE: (%d, %d)", mx, my), 10, 90)
    love.graphics.print("Window: " .. (engine.showWorldGenWindow and "VISIBLE" or "HIDDEN"), 10, 110)

    -- ==================== CRITICAL FIX: Define SLAB elements BEFORE Draw ====================

    -- 1. Define main menu bar
    UI.drawMenuBar(engine)

    -- 2. Define window (if visible)
    UI.drawWorldGenWindow(engine, screenW, screenH)

    -- 3. Draw EVERYTHING at once
    SLAB.Draw()
end

function love.keyreleased(key)
    Input.keyreleased(key)
end

function love.keypressed(key)
    Input.keypressed(key)

    if key == "f5" then
        engine.showWorldGenWindow = not engine.showWorldGenWindow
        engine.seedInputText = tostring(engine.gameData.worldSeed or engine.generateRandomSeed())
        engine.f5Debug = string.format("Pressed at %s", os.date("%H:%M:%S"))
        print(string.format("F5 toggled: Window %s", engine.showWorldGenWindow and "OPEN" or "CLOSED"))
    end

    if key == "q" or key == "escape" then
        if engine.showWorldGenWindow then
            engine.showWorldGenWindow = false
        else
            love.event.quit()
        end
    end
end