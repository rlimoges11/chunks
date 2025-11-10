local Input = {}

Input.keysPressed = {}

function Input.keypressed(key)
    Input.keysPressed[key] = true

    -- WASD support
    if key == "a" then Input.keysPressed["left"] = true end
    if key == "d" then Input.keysPressed["right"] = true end
    if key == "w" then Input.keysPressed["up"] = true end
    if key == "s" then Input.keysPressed["down"] = true end
end

function Input.keyreleased(key)
    Input.keysPressed[key] = nil

    -- WASD support
    if key == "a" then Input.keysPressed["left"] = nil end
    if key == "d" then Input.keysPressed["right"] = nil end
    if key == "w" then Input.keysPressed["up"] = nil end
    if key == "s" then Input.keysPressed["down"] = nil end
end

function Input.getMovement()
    local moveX, moveY = 0, 0
    if Input.keysPressed["left"] then moveX = moveX - 1 end
    if Input.keysPressed["right"] then moveX = moveX + 1 end
    if Input.keysPressed["up"] then moveY = moveY - 1 end
    if Input.keysPressed["down"] then moveY = moveY + 1 end
    return moveX, moveY
end

return Input