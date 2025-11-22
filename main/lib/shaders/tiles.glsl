// tiles.glsl

// Pseudo-random number generator (hash function)
float rand(vec2 n) { 
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 43758.5453);
}

// 2D noise function
float noise2D(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    
    // Four corners in 2D of a tile
    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));
    
    // Smooth interpolation with cubic curve
    vec2 u = f * f * (3.0 - 2.0 * f);
    
    // Mix 4 coorners percentages
    return mix(a, b, u.x) + 
           (c - a) * u.y * (1.0 - u.x) + 
           (d - b) * u.x * u.y;
}

extern Image u_tileset;
extern vec2 u_tileset_size;
extern float u_tile_px;
extern vec2 u_camera_pos;
extern float u_zoom;
extern vec2 u_screen_size;
extern vec2 u_chunk_origin;
extern float u_chunk_px;
extern float u_tile_count; // number of tiles used
extern float u_tileset_cols; // tileset width in tiles

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec2 world = u_camera_pos + (screen_coords - 0.5 * u_screen_size) / u_zoom;

    vec2 local = (world - u_chunk_origin) / u_chunk_px;
    float invChunk = 1.0 / u_chunk_px;
    local = clamp(local, 0.0, 1.0 - invChunk);
    // Sample the red channel to get the tile index
    float r = Texel(texture, local).r;
    
    // Calculate the tile index (0 to count-1)
    float count = floor(u_tile_count + 0.5);
    
    // Add a small epsilon to handle floating point precision issues
    float idx = floor(r * count + 0.0001);
    
    // Clamp the index to valid range
    idx = clamp(idx, 0.0, max(count - 1.0, 0.0));
    
    // Calculate the tile's position in the tileset
    float cols = max(1.0, floor(u_tileset_cols + 0.5));
    float tileX = mod(idx, cols);
    float tileY = floor(idx / cols);
    
    // Calculate the pixel coordinates within the tile
    vec2 pixelInTile = fract(world) * u_tile_px;
    
    // Calculate the final UV coordinates
    vec2 tileOffset = vec2(tileX * u_tile_px, tileY * u_tile_px);
    
    // Generate per-tile coordinate for consistent noise
    vec2 tilePixelPos = floor(world);
    vec2 withinTile = fract(world);
    
    // Generate per-pixel noise based on tile position
    float pixelNoise = rand(tilePixelPos) * 0.1 - 0.05; // ±0.05 range
    
    // Calculate UVs with a small offset to prevent filtering artifacts
    vec2 uv = (tileOffset + pixelInTile) / u_tileset_size;
    
    // Sample the tile with the slightly perturbed UVs
    vec4 tileColor = Texel(u_tileset, uv);

    // Get pre-blurred noise from blue channel
    float noise = Texel(texture, local).b * 0.35;
    
    // Add subtle per-pixel noise (using sub-pixel world position)
    float screenNoise = rand(world * 10.0) * 0.1 - 0.05; // ±0.05 range
    
    // Check if the pixel is water-colored (#4ebcb9 in sRGB)
    vec3 waterColor = vec3(0.3059, 0.7373, 0.7255); // #4ebcb9 in sRGB
    float waterThreshold = 0.1; // How close to water color to consider it water
    vec3 diff = abs(tileColor.rgb - waterColor);
    bool isWaterPixel = all(lessThan(diff, vec3(waterThreshold)));
    
    // Only apply to non-water pixels
    if (!isWaterPixel) {
        tileColor.rgb += screenNoise;
    }
    
    tileColor.rgb -= noise;

    // Apply green channel blend with original texture
    float greenValue = Texel(texture, local).g + noise;
    tileColor = mix(tileColor, vec4(greenValue, greenValue, greenValue, 1), 0.45);

    return tileColor * color;
}
