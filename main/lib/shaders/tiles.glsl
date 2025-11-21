// tiles.glsl

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
    vec2 uv = (tileOffset + pixelInTile) / u_tileset_size;
    
    // Sample the water tile
    vec4 tileColor = Texel(u_tileset, uv);
    
        // Sample the original green channel from the texture
        float greenValue = Texel(texture, local).g;
        // Blend the water with the original green texture (adjust the blend factor as needed)
        tileColor = mix(tileColor, vec4(greenValue/2, greenValue/2, greenValue/2, 0.5), 0.25);

    return tileColor * color;
}
