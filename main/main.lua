local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local Camera = require("lib.vendor.hump.camera")
local lfs = require("love.filesystem")
local Perlin = require("lib.modules.perlin")
local Input = require("lib.modules.input")
local UI = require("lib.modules.ui")

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
    isClearing = false,
    -- NEW ZOOM PROPERTIES
    zoom = 1.0,
    minZoom = 1,
    maxZoom = 16.0,
    zoomSpeed = 1.1,
    shaderTiles = nil,
    tilesetImage = nil,
    tilePx = 16,
    tileThreshold = 0.3
}

if not lfs.getInfo(engine.assetsDir) then
    print("Creating assets directory:", engine.assetsDir)
    lfs.createDirectory(engine.assetsDir)
end

local function getTerrainColor(noiseValue)
    local n = noiseValue + 0.5
    if n < 0.05 then return 0.5,0.5,0.5
    elseif n < 0.1 then return 0.35,0.35,0.35
    elseif n < 0.2 then return 0.2, 0.15, 0.1
    elseif n < 0.4 then return 0.5, 0.4, 0.25
    elseif n > 0.85 then return 0.5,0.5,0.5
    elseif n > 0.6 then return 0.35,0.35,0.35
    else return 0.025,0.025,0.025
    end
end

-- World management (atomic clearing)
function engine.clearWorld()
    engine.isClearing = true  -- Block generation
    engine.images = {}  -- Clear memory

    -- Clear disk files
    local items = lfs.getDirectoryItems(engine.assetsDir)
    local count = 0
    for _, item in ipairs(items) do
        if item:match("^cell_%d+_%d+%.png$") then
            local success = lfs.remove(engine.assetsDir .. item)
            if success then count = count + 1 end
        end
    end

    engine.isClearing = false  -- Allow generation again
    engine.statusText = string.format("Cleared %d files - ready for new generation", count)
    print(engine.statusText)
end

function engine.applyNewSeed(newSeed)
    local seed = tonumber(newSeed) or math.random(1, 999999)
    engine.gameData.worldSeed = seed
    engine.perlin = Perlin:new(seed)
    engine.clearWorld()  -- Clears AND blocks generation
    engine.showWorldGenWindow = false
    engine.statusText = string.format("NEW SEED APPLIED: %d - World cleared", seed)
    print("Applied seed and cleared world:", seed)
end

function engine.generateRandomSeed()
    return math.random(1, 999999)
end

function engine.generateCellImage(i, j, size)
    if engine.isClearing then
        print("GENERATION BLOCKED: Clearing in progress")
        return nil
    end

    print(string.format("Generating cell %d,%d...", i, j))
    local imgData = love.image.newImageData(size, size)

    for py = 0, size-1 do
        for px = 0, size-1 do
            local wx, wy = i * size + px, j * size + py
            local noise = engine.perlin:octaveNoise(wx, wy, 4, 0.65)
            local r, g, b = getTerrainColor(noise)
            imgData:setPixel(px, py, r, g, b, 1)
        end
    end

    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    local success = pcall(function() return imgData:encode("png", filename) end)
    if not success then print("Save failed") return nil end

    local img = love.graphics.newImage(imgData)
    img:setFilter('nearest', 'nearest')
    if img.setWrap then img:setWrap('clamp','clamp') end
    engine.images[i] = engine.images[i] or {}
    engine.images[i][j] = img
    print(string.format("Saved cell %d,%d", i, j))
    return img
end

function engine.getCellImage(i, j, size)
    if engine.isClearing then return nil end  -- Block during clear

    -- Initialize the row if it doesn't exist
    if not engine.images[i] then engine.images[i] = {} end
    
    -- Return cached image if it exists
    if engine.images[i][j] then 
        return engine.images[i][j] 
    end

    -- Only load/generate the image if we don't have it cached
    local filename = string.format("%s/cell_%d_%d.png", engine.assetsDir, i, j)
    if lfs.getInfo(filename) then
        local success, img = pcall(function() 
            local img = love.graphics.newImage(filename)
            img:setFilter('nearest', 'nearest')
            if img.setWrap then img:setWrap('clamp','clamp') end
            return img
        end)
        
        if success and img then
            engine.images[i][j] = img
            return img
        else
            -- If loading failed, remove the corrupted file
            lfs.remove(filename)
        end
    end
    
    -- Only generate new images if they're likely to be visible
    local screenW, screenH = love.graphics.getDimensions()
    local camX, camY = engine.camera:position()
    local viewLeft = camX - screenW/2
    local viewRight = camX + screenW/2
    local viewTop = camY - screenH/2
    local viewBottom = camY + screenH/2
    
    local chunkX, chunkY = i * size, j * size
    
    -- Only generate if the chunk is within the extended viewport
    if chunkX + size * 2 >= viewLeft and 
       chunkX <= viewRight * 1.5 and 
       chunkY + size * 2 >= viewTop and 
       chunkY <= viewBottom * 1.5 then
        return engine.generateCellImage(i, j, size)
    end
    
    return nil
end

function engine.init()
    engine.camera = Camera(0, 0)
    engine.camera.smoother = function() return 1 end
    engine.zoom = engine.gameData.camera.scale or 1
    engine.camera:zoomTo(engine.zoom)  -- Apply zoom

    local seed = engine.gameData.worldSeed or os.time()
    engine.perlin = Perlin:new(seed)
    engine.seedInputText = tostring(seed)
    engine.camSpeed = engine.gameData.camera.moveSpeed
    engine.isClearing = false
    engine.statusText = "Press F5 to open world manager | Scroll to zoom"
    print("Engine initialized - Seed:", seed, "Zoom:", engine.zoom)

    local tilesetPath = "dat/img/tilesets/ground.png"
    if lfs.getInfo(tilesetPath) then
        engine.tilesetImage = love.graphics.newImage(tilesetPath)
        engine.tilesetImage:setFilter('nearest', 'nearest')
        if engine.tilesetImage.setWrap then engine.tilesetImage:setWrap('clamp','clamp') end
        local ok, shader = pcall(function()
            return love.graphics.newShader("lib/shaders/tiles.glsl")
        end)
        if ok and shader then
            engine.shaderTiles = shader
            shader:send("u_tileset", engine.tilesetImage)
            shader:send("u_tileset_size", { engine.tilesetImage:getWidth(), engine.tilesetImage:getHeight() })
            shader:send("u_tile_px", engine.tilePx)
            shader:send("u_threshold_water", engine.tileThreshold)
            local tilesStr = love.filesystem.read("dat/json/tiles.json")
            if tilesStr then
                local tilesData = JSON.decode(tilesStr)
                if tilesData and tilesData.ground then
                    local grassX, grassY, waterX, waterY = 16, 16, 48, 32
                    for _, t in ipairs(tilesData.ground) do
                        if t.name == "grass" then
                            local x, y = string.match(t.offset, "(%-?%d+),(%-?%d+)")
                            if x and y then grassX, grassY = tonumber(x), tonumber(y) end
                        elseif t.name == "water" then
                            local x, y = string.match(t.offset, "(%-?%d+),(%-?%d+)")
                            if x and y then waterX, waterY = tonumber(x), tonumber(y) end
                        end
                    end
                    shader:send("u_tile_grass_offset", { grassX, grassY })
                    shader:send("u_tile_water_offset", { waterX, waterY })
                end
            end
        else
            engine.shaderTiles = nil
        end
    else
        print("Tileset not found at:", tilesetPath)
    end
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
    local size = engine.gameData.chunkSize
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Get camera position in world coordinates
    local camX, camY = engine.camera:position()
    
    -- Calculate viewport bounds in world coordinates, accounting for zoom
    local viewLeft = camX - (screenW / 2) / engine.zoom
    local viewRight = camX + (screenW / 2) / engine.zoom
    local viewTop = camY - (screenH / 2) / engine.zoom
    local viewBottom = camY + (screenH / 2) / engine.zoom
    
    -- Convert world coordinates to grid coordinates
    -- Use math.floor and math.ceil to ensure we get all chunks that intersect the view
    local gridStartX = math.floor(viewLeft / size)
    local gridStartY = math.floor(viewTop / size)
    local gridEndX = math.ceil(viewRight / size)
    local gridEndY = math.ceil(viewBottom / size)
    
    -- Calculate load boundaries with a small buffer that scales with zoom
    local loadBuffer = math.max(1, math.ceil(2 / engine.zoom))
    
    -- Calculate load boundaries without restricting to positive values
    -- This allows loading chunks in negative coordinates
    local loadStartX = gridStartX - loadBuffer
    local loadStartY = gridStartY - loadBuffer
    local loadEndX = gridEndX + loadBuffer
    local loadEndY = gridEndY + loadBuffer
    
    if engine.shaderTiles and engine.tilesetImage then
        engine.shaderTiles:send("u_camera_pos", { engine.camX, engine.camY })
        engine.shaderTiles:send("u_zoom", engine.zoom)
        engine.shaderTiles:send("u_screen_size", { screenW, screenH })
        love.graphics.setShader(engine.shaderTiles)
    end
    engine.camera:attach()
    
    -- First pass: Load/generate visible chunks
    for j = loadStartY, loadEndY do
        for i = loadStartX, loadEndX do
            -- Calculate chunk's world position
            local chunkX, chunkY = i * size, j * size
            
            -- Check if chunk intersects with the extended viewport
            -- The extended viewport includes a buffer area around the screen
            local extendedLeft = viewLeft - (loadBuffer * size)
            local extendedRight = viewRight + (loadBuffer * size)
            local extendedTop = viewTop - (loadBuffer * size)
            local extendedBottom = viewBottom + (loadBuffer * size)
            
            -- Check for intersection between chunk and extended viewport
            if chunkX + size >= extendedLeft and chunkX <= extendedRight and
               chunkY + size >= extendedTop and chunkY <= extendedBottom then
                engine.getCellImage(i, j, size)
            end
        end
    end
    
    -- Second pass: Draw only the visible chunks
    for j = gridStartY, gridEndY do
        for i = gridStartX, gridEndX do
            local x, y = i * size, j * size
            
            -- Skip if completely outside viewport (with some padding)
            if x + size < viewLeft or x > viewRight or
               y + size < viewTop or y > viewBottom then
                goto continue
            end
            
            local img = engine.images[i] and engine.images[i][j]
            if img then
                if engine.shaderTiles and engine.tilesetImage then
                    engine.shaderTiles:send("u_chunk_origin", { x, y })
                    engine.shaderTiles:send("u_chunk_px", size)
                end
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(img, x, y, 0, 1, 1)
            end
            ::continue::
        end
    end
    engine.camera:detach()
    if engine.shaderTiles and engine.tilesetImage then
        love.graphics.setShader()
    end

    -- Clear status if clearing is done
    if engine.isClearing then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.print("CLEARING WORLD...", 10, 130)
    end

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

    -- INSTANT F5 HANDLING
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

function love.wheelmoved(x, y)
    if y > 0 then
        engine.zoom = math.min(engine.zoom * engine.zoomSpeed, engine.maxZoom)
    elseif y < 0 then
        engine.zoom = math.max(engine.zoom / engine.zoomSpeed, engine.minZoom)
    end
    engine.camera:zoomTo(engine.zoom)
end