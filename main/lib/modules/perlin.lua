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
    for i = 0, 255 do self.perm[i+1] = i end
    for i = 0, 255 do
        local j = math.random(0, 255)
        self.perm[i+1], self.perm[j+1] = self.perm[j+1], self.perm[i+1]
    end
    for i = 0, 255 do self.perm[i + 257] = self.perm[i + 1] end
end

function Perlin:fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
function Perlin:lerp(t, a, b) return a + t * (b - a) end

function Perlin:grad(hash, x, y)
    local h = hash % 4
    local u = (h < 2) and x or -x
    local v = (h < 1 or h == 3) and y or -y
    return u + v
end

function Perlin:noise(x, y)
    local scale = 0.01
    x, y = x * scale, y * scale
    local X, Y = math.floor(x) % 256, math.floor(y) % 256
    local xf, yf = x - math.floor(x), y - math.floor(y)
    local u, v = self:fade(xf), self:fade(yf)

    local a = self.perm[X + 1] + Y
    local aa, ab = self.perm[a + 1], self.perm[a + 2]
    local b = self.perm[X + 2] + Y
    local ba, bb = self.perm[b + 1], self.perm[b + 2]

    return self:lerp(v, self:lerp(u, self:grad(self.perm[aa + 1], xf, yf),
            self:grad(self.perm[ba + 1], xf - 1, yf)),
            self:lerp(u, self:grad(self.perm[ab + 1], xf, yf - 1),
                    self:grad(self.perm[bb + 1], xf - 1, yf - 1)))
end

function Perlin:octaveNoise(x, y, octaves, persistence)
    local value, amplitude, frequency, maxValue = 0, 1, 1, 0
    for i = 1, octaves do
        value = value + self:noise(x * frequency, y * frequency) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * 2
    end
    return value / maxValue
end

return Perlin