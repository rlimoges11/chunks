local JSON = require("lib.vendor.json_min")
local FLUX = require("lib.vendor.flux_min")
local SLAB = require("lib.vendor.slab")
local engine = {}
local keysPressed={}
engine.gameData = {}


function love.load(args)
    engine.gameData = JSON.decode(love.filesystem.read("dat/json/game.json"))
    love.window.setMode(engine.gameData.window.width, engine.gameData.window.height, {vsync = engine.gameData.window.vsync, resizable = engine.gameData.window.resizable})
    love.window.setFullscreen(engine.gameData.window.fullscreen, "desktop")
    engine.font = love.graphics.newFont("dat/fonts/ZenDots-Regular.ttf", 52)
    engine.fHeight = engine.font:getHeight()
end
function love.keyreleased(key)
    keysPressed[key] = nil
end
function love.keypressed(key)
    keysPressed[key] = true
    if key == "q" or key == "escape" then
        love.event.quit()
    end
end