local Input = {}

Input.keysPressed = {}

function Input.keypressed(key)
    Input.keysPressed[key] = true

    -- WASD support (maps to arrow keys)
    if key == "a" then Input.keysPressed["left"] = true
    elseif key == "d" then Input.keysPressed["right"] = true
    elseif key == "w" then Input.keysPressed["up"] = true
    elseif key == "s" then Input.keysPressed["down"] = true
    end
end

function Input.keyreleased(key)
    Input.keysPressed[key] = nil

    -- WASD support
    if key == "a" then Input.keysPressed["left"] = nil
    elseif key == "d" then Input.keysPressed["right"] = nil
    elseif key == "w" then Input.keysPressed["up"] = nil
    elseif key == "s" then Input.keysPressed["down"] = nil
    end
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