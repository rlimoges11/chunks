local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local Camera = require("lib.vendor.hump.camera")
local lfs = require("love.filesystem")

-- Simple Perlin noise implementation
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

local engine = {
    gameData = {},
    chunks = {},
    keysPressed = {},
    camera = {},
    camX = 0,
    camY = 0,
    images = {},
    assetsDir = "dat/grid_assets/",
    perlin = nil
}

-- Ensure assets directory exists
if not lfs.getInfo(engine.assetsDir) then
    print("Creating assets directory:", engine.assetsDir)
    lfs.createDirectory(engine.assetsDir)
end

-- Terrain color mapping
local function getTerrainColor(noiseValue)
    local n = (noiseValue + 1) / 2

    if n < 0.3 then
        return 0.1, 0.3, 0.8      -- Deep water
    elseif n < 0.4 then
        return 0.2, 0.5, 0.9      -- Shallow water
    elseif n < 0.5 then
        return 0.9, 0.8, 0.6      -- Sand/beach
    elseif n < 0.7 then
        return 0.3, 0.7, 0.2      -- Grass
    elseif n < 0.85 then
        return 0.4, 0.5, 0.2      -- Forest/dirt
    else
        return 0.6, 0.6, 0.6      -- Rock/mountain
    end
end

-- Function to generate a unique image for a grid cell
function engine.generateCellImage(i, j, size)
    print(string.format("Generating cell %d,%d...", i, j))

    -- Create a new ImageData for the cell
    local imgData = love.image.newImageData(size, size)

    -- Generate Perlin noise per-pixel (WORLD-SPACE coordinates)
    for py = 0, size-1 do
        for px = 0, size-1 do
            local worldX = i * size + px
            local worldY = j * size + py

            -- Sample noise at this exact pixel position
            local noiseValue = engine.perlin:octaveNoise(worldX, worldY, 4, 0.5)
            local r, g, b = getTerrainColor(noiseValue)

            imgData:setPixel(px, py, r, g, b, 1)
        end
    end

    -- **SAVE TO FILE**
    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    print(string.format("Saving to: %s", filename))

    local success, err = pcall(function()
        return imgData:encode("png", filename)
    end)

    if not success then
        print("ERROR: Failed to save image:", err)
        return nil
    else
        print("File saved successfully")
    end

    -- Create the final image
    local finalImage = love.graphics.newImage(imgData)
    if not finalImage then
        print("ERROR: Failed to create final image for cell", i, j)
        return nil
    end

    -- Store in memory cache
    engine.images[i] = engine.images[i] or {}
    engine.images[i][j] = finalImage

    print(string.format("Successfully generated cell %d,%d", i, j))
    return finalImage
end

-- Function to get a cell image, generate if not exists
function engine.getCellImage(i, j, size)
    engine.images[i] = engine.images[i] or {}

    -- Return from cache if exists
    if engine.images[i][j] then
        return engine.images[i][j]
    end

    -- Check if file exists on disk
    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    local fileInfo = lfs.getInfo(filename)

    if fileInfo then
        print(string.format("Loading existing image: %s", filename))
        local success, img = pcall(function()
            return love.graphics.newImage(filename)
        end)

        if success and img then
            engine.images[i][j] = img
            return img
        else
            print(string.format("Failed to load, regenerating: %s", tostring(img)))
            if fileInfo then
                os.remove(filename)
            end
        end
    end

    -- Generate new image
    return engine.generateCellImage(i, j, size)
end

function engine.init(args)
    engine.camSpeed = engine.gameData.camera.moveSpeed

    -- Initialize Perlin noise
    local seed = engine.gameData.worldSeed or os.time()
    engine.perlin = Perlin:new(seed)
    print("Perlin noise initialized with seed:", seed)

    -- Initialize camera
    engine.camera = Camera(0, 0)
    engine.camera.smoother = function() return 1 end
    engine.camera:zoom(1)
end

function love.update(dt)
    local moveX, moveY = 0, 0

    if engine.keysPressed["left"] then
        moveX = moveX - 1
    end
    if engine.keysPressed["right"] then
        moveX = moveX + 1
    end
    if engine.keysPressed["up"] then
        moveY = moveY - 1
    end
    if engine.keysPressed["down"] then
        moveY = moveY + 1
    end

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

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("Camera: (%.1f, %.1f)", engine.camX, engine.camY), 10, 30)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 50)
end

function love.load(args)
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

function love.keyreleased(key)
    engine.keysPressed[key] = nil
end

function love.keypressed(key)
    engine.keysPressed[key] = true
    if key == "q" or key == "escape" then
        love.event.quit()
    end
end