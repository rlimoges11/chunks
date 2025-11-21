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
    float r = Texel(texture, local).r;

    float count = floor(u_tile_count + 0.5);
    float idx = floor(r * count);
    idx = clamp(idx, 0.0, max(count - 1.0, 0.0));

    float cols = max(1.0, floor(u_tileset_cols + 0.5));
    float c = mod(idx, cols);
    float rr = floor(idx / cols);
    vec2 tileOffset = vec2(c * u_tile_px, rr * u_tile_px);

    vec2 pixelFrac = fract(world);
    vec2 intra = pixelFrac * (u_tile_px - 1.0) + 0.5;
    vec2 uv = (tileOffset + intra) / u_tileset_size;

    return Texel(u_tileset, uv) * color;
}
