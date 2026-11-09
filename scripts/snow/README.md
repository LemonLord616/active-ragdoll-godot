# Snow field prefab

`scenes/prefabs/snow.tscn` is a drop-in snow shell that conforms to flat ground
or Terrain3D. It needs no collision: imprints are captured from rendered
geometry by an upward-looking orthographic depth camera.

## Quick start

1. Instance `scenes/prefabs/snow.tscn` in your scene.
2. Put the root at the centre of the area you want covered. The root Y is the
   ground height for flat scenes; with Terrain3D the actual height is sampled
   from the terrain.
3. Set `area_size` on the root (default 100 m square).
4. Put objects that should leave prints on the influence layer (default 5).
   Keep the terrain, ground and snow surface off that layer.

The depth camera cull mask is built automatically from `influence_layer`, so
moving a visual to layer 5 is enough. The visual can stay on other layers too
(for example `layers = 17` keeps layer 1 and adds layer 5).

## Terrain3D

The first `Terrain3D` node in the current scene is found automatically. Set
`terrain_path` if you have several and want to pick one. The initial bake waits
two frames for Terrain3D to load its regions; call `rebake()` after editing the
terrain or moving the snow field at runtime.

- `slope_limit_degrees` / `slope_fade_degrees` control where snow cannot settle.
- `edge_fade` softens the border of the square field.
- `height_resolution` is the terrain sample grid (256 is fine for most terrain).
- `mask_resolution` controls the mask viewport (512); `mesh_resolution` controls geometry (256).
- `snow_max_height` is the depth of untouched snow, in metres.
- `snow_offset` keeps the shell above the terrain to avoid z-fighting.

Without Terrain3D the prefab behaves like the original flat snow field: the
snow base is the root's Y.

## Renderers

Forward+ and Compatibility are both supported. The mask shader and
`snow_field.gd` handle the renderer differences (depth NDC range and mask
viewport colour space). The snow shader samples the mask with `texelFetch` in
both stages because Compatibility cannot combine it with `texture()` on the
same ViewportTexture.

## Tests

- `tests/snow_flat_test.tscn` - flat ground regression, prints and mask capture.
- `tests/snow_terrain_test.tscn` - Terrain3D conformity and prints.
- `tests/snow_terrain_multi_test.tscn` - two independent fields on Terrain3D.

Run them with `godot --path . tests/<scene>.tscn`; screenshots are written to
`/tmp/opencode`.

Snow appearance is procedural; no PNG textures are required. See `docs/snow-report.md` for setup, research, changes and limitations.

`deformation_smoothing` sets contact smoothing radius in metres (default 0.15).
Zero gives sharp contacts. It can change live; reset the mask or rebake to remove
old sharp imprints. Try 0.1–0.3 for boots. Larger values soften and shallow prints.
