local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local Camera = require("lib.vendor.hump.camera")
local engine = {
    gameData = {},
    chunks={},
    keysPressed={},
    camera = {},
    camX = 0,
    camY = 0,
}

function engine.init(args)
    engine.camSpeed = engine.gameData.camera.moveSpeed
    engine.camera = Camera(0, 0)
end
function love.update(dt)
    if engine.keysPressed["left"] then
        engine.camX = engine.camX - engine.camSpeed * dt
    end
    if engine.keysPressed["right"] then
        engine.camX = engine.camX + engine.camSpeed * dt
    end
    if engine.keysPressed["up"] then
        engine.camY = engine.camY - engine.camSpeed * dt
    end
    if engine.keysPressed["down"] then
        engine.camY = engine.camY + engine.camSpeed * dt
    end
    local screenW, screenH = love.graphics.getDimensions()
    engine.camera:lookAt(engine.camX + screenW/2, engine.camY + screenH/2)
end
function love.draw()
    engine.camera:attach()
    
    local size = engine.gameData.chunkSize
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Calculate visible grid bounds based on camera position
    local camX, camY = engine.camera:position()
    local startX = math.floor((camX - screenW/2) / size) - 1
    local startY = math.floor((camY - screenH/2) / size) - 1
    local endX = startX + math.ceil(screenW / size) + 2
    local endY = startY + math.ceil(screenH / size) + 2
    
    -- Draw grid
    for j = startY, endY do
        for i = startX, endX do
            engine.chunks[i] = engine.chunks[i] or {}
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.rectangle("line", i * size, j * size, size, size)
        end
    end
    engine.camera:detach()
    
    -- Draw UI
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("Camera: (%.1f, %.1f)", engine.camX, engine.camY), 10, 30)
end
function love.load(args)
    engine.gameData = JSON.decode(love.filesystem.read("dat/json/game.json"))
    love.window.setMode(engine.gameData.window.width, engine.gameData.window.height, {vsync = engine.gameData.window.vsync, resizable = engine.gameData.window.resizable})
    love.window.setFullscreen(engine.gameData.window.fullscreen, "desktop")
    engine.font = love.graphics.newFont("dat/fonts/ZenDots-Regular.ttf", 52)
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