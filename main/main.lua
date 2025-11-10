local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local engine = {
    gameData = {},
    chunks={},
    keysPressed={}
}

function engine.init(args)
end

function love.update()
end
function love.draw()
    local size = engine.gameData.chunkSize
    for j = 0, love.graphics.getHeight() / size do
        for i = 0, love.graphics.getWidth() / size do
            engine.chunks[i] = {}
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.rectangle("line", i * size, j*size, size, size)
        end
    end
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