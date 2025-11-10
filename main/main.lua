local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local Camera = require("lib.vendor.hump.camera")
local lfs = require("love.filesystem")

-- ==================== PERLIN NOISE CLASS ====================

local Perlin = {}
Perlin.__index = Perlin

function Perlin:new(seed)
    local obj = setmetatable({}, Perlin)
    obj.seed = seed or 0
    obj.perm = {}
    obj:init()
    return obj
end

function Perlin:init()
    math.randomseed(self.seed)
    for i = 0, 255 do
        self.perm[i+1] = i
    end
    for i = 0, 255 do
        local j = math.random(0, 255)
        self.perm[i+1], self.perm[j+1] = self.perm[j+1], self.perm[i+1]
    end
    for i = 0, 255 do
        self.perm[i + 257] = self.perm[i + 1]
    end
end

function Perlin:fade(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

function Perlin:lerp(t, a, b)
    return a + t * (b - a)
end

function Perlin:grad(hash, x, y)
    local h = hash % 4
    local u = (h < 2) and x or -x
    local v = (h < 1 or h == 3) and y or -y
    return u + v
end

function Perlin:noise(x, y)
    local scale = 0.01
    x = x * scale
    y = y * scale

    local X = math.floor(x) % 256
    local Y = math.floor(y) % 256
    local xf = x - math.floor(x)
    local yf = y - math.floor(y)

    local u = self:fade(xf)
    local v = self:fade(yf)

    local a = self.perm[X + 1] + Y
    local aa = self.perm[a + 1]
    local ab = self.perm[a + 2]
    local b = self.perm[X + 2] + Y
    local ba = self.perm[b + 1]
    local bb = self.perm[b + 2]

    return self:lerp(v,
            self:lerp(u, self:grad(self.perm[aa + 1], xf, yf),
                    self:grad(self.perm[ba + 1], xf - 1, yf)),
            self:lerp(u, self:grad(self.perm[ab + 1], xf, yf - 1),
                    self:grad(self.perm[bb + 1], xf - 1, yf - 1)))
end

function Perlin:octaveNoise(x, y, octaves, persistence)
    local value = 0
    local amplitude = 1
    local frequency = 1
    local maxValue = 0

    for i = 1, octaves do
        value = value + self:noise(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end

    return value / maxValue
end

-- ==================== ENGINE TABLE & STATE ====================

local engine = {
    gameData = {},
    chunks = {},
    keysPressed = {},
    camera = nil,  -- FIX: Start as nil instead of {}
    camX = 0,
    camY = 0,
    images = {},
    assetsDir = "dat/grid_assets/",
    perlin = nil,
    showWorldGenWindow = false,
    seedInputText = ""
}

-- Ensure assets directory exists
if not lfs.getInfo(engine.assetsDir) then
    print("Creating assets directory:", engine.assetsDir)
    lfs.createDirectory(engine.assetsDir)
end

-- Terrain color mapping
local function getTerrainColor(noiseValue)
    local n = (noiseValue + 1) / 2
    if n < 0.3 then return 0.1, 0.3, 0.8 -- Deep water
    elseif n < 0.4 then return 0.2, 0.5, 0.9 -- Shallow water
    elseif n < 0.5 then return 0.9, 0.8, 0.6 -- Sand
    elseif n < 0.7 then return 0.3, 0.7, 0.2 -- Grass
    elseif n < 0.85 then return 0.4, 0.5, 0.2 -- Forest
    else return 0.6, 0.6, 0.6 -- Mountain
    end
end

-- World management
function engine.clearWorld()
    engine.images = {}
    local items = lfs.getDirectoryItems(engine.assetsDir)
    local count = 0
    for _, item in ipairs(items) do
        if item:match("^cell_%d+_%d+%.png$") then
            local filepath = engine.assetsDir .. item
            local success = lfs.remove(filepath)
            if success then count = count + 1 end
        end
    end
    print(string.format("Cleared %d files", count))
end

function engine.applyNewSeed(newSeed)
    local seed = tonumber(newSeed) or math.random(1, 999999)
    engine.gameData.worldSeed = seed
    engine.perlin = Perlin:new(seed)
    engine.clearWorld()
    engine.showWorldGenWindow = false
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
            local wx = i * size + px
            local wy = j * size + py
            local noise = engine.perlin:octaveNoise(wx, wy, 4, 0.5)
            local r, g, b = getTerrainColor(noise)
            imgData:setPixel(px, py, r, g, b, 1)
        end
    end

    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    local success, err = pcall(function() return imgData:encode("png", filename) end)
    if not success then
        print("Save ERROR:", err)
        return nil
    end

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

-- ==================== INIT FUNCTION (FIXED) ====================
-- THIS WAS MISSING!

function engine.init(args)
    -- Initialize camera
    engine.camera = Camera(0, 0)
    engine.camera.smoother = function() return 1 end
    engine.camera:zoom(1)

    -- Initialize Perlin noise
    local seed = engine.gameData.worldSeed or os.time()
    engine.perlin = Perlin:new(seed)
    engine.seedInputText = tostring(seed)
    engine.camSpeed = engine.gameData.camera.moveSpeed or 300

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
    engine.init(args)
end

function love.update(dt)
    SLAB.Update(dt)

    local moveX, moveY = 0, 0
    if engine.keysPressed["left"] then moveX = moveX - 1 end
    if engine.keysPressed["right"] then moveX = moveX + 1 end
    if engine.keysPressed["up"] then moveY = moveY - 1 end
    if engine.keysPressed["down"] then moveY = moveY + 1 end

    local len = math.sqrt(moveX * moveX + moveY * moveY)
    if len > 0 then
        moveX = moveX / len * engine.camSpeed * dt
        moveY = moveY / len * engine.camSpeed * dt
    end

    engine.camX = engine.camX + moveX
    engine.camY = engine.camY + moveY
    engine.camera:lookAt(engine.camX, engine.camY)

    if engine.keysPressed["f5"] then
        engine.showWorldGenWindow = true
        engine.seedInputText = tostring(engine.gameData.worldSeed or engine.generateRandomSeed())
    end
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

    -- Draw world
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

    -- Display seed and stats
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("SEED: %d (F5 to regenerate)", engine.gameData.worldSeed or 0), 10, 10)
    love.graphics.print(string.format("Camera: (%.1f, %.1f)", engine.camX, engine.camY), 10, 30)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 50)

    -- Draw SLAB UI
    SLAB.Draw()

    -- World generation window
    if engine.showWorldGenWindow then
        local windowW, windowH = 400, 200
        SLAB.BeginWindow('WorldGenWindow', {
            Title = "Generate New World",
            X = screenW/2 - windowW/2,
            Y = screenH/2 - windowH/2,
            W = windowW,
            H = windowH,
            AutoSizeWindow = false,
            Border = 20
        })

        SLAB.Text("Current Seed: " .. (engine.gameData.worldSeed or 0))
        SLAB.Separator()
        SLAB.Text("New Seed:")
        SLAB.SameLine()
        SLAB.PushItemWidth(150)
        if SLAB.Input('SeedInput', {Text = engine.seedInputText}) then
            engine.seedInputText = SLAB.GetInputText()
        end
        SLAB.PopItemWidth()
        SLAB.SameLine()

        if SLAB.Button('Randomize') then
            engine.seedInputText = tostring(engine.generateRandomSeed())
        end

        SLAB.Separator()

        if SLAB.Button('Generate') then
            engine.applyNewSeed(engine.seedInputText)
        end

        SLAB.SameLine()

        if SLAB.Button('Cancel') then
            engine.showWorldGenWindow = false
        end

        SLAB.EndWindow()
    end

    -- Main menu bar
    if SLAB.BeginMainMenuBar() then
        if SLAB.BeginMenu("File") then
            if SLAB.MenuItem("Generate New World") then
                engine.showWorldGenWindow = true
                engine.seedInputText = tostring(engine.gameData.worldSeed or engine.generateRandomSeed())
            end
            SLAB.EndMenu()
        end
        SLAB.EndMainMenuBar()
    end
end

function love.keyreleased(key)
    engine.keysPressed[key] = nil
end

function love.keypressed(key)
    engine.keysPressed[key] = true

    if key == "q" or key == "escape" then
        love.event.quit()
    end
end

function love.mousepressed(x, y, button) end
function love.mousereleased(x, y, button) end
function love.textinput(text) end