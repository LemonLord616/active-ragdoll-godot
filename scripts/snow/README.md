# Standalone snow

Instance `scenes/prefabs/snow.tscn`. Assign the exported `terrain` reference;
leave it empty for flat ground. No terrain nodes are discovered at runtime.

The root X/Z scale is the footprint in metres (20, 1, 20 gives 20 x 20 m).
Keep rotation zero and scale positive. Y scale does not change snow depth.
Set depth with `snow_max_height`. Mesh and mask resolutions control detail.

Press **Bake snow** in the inspector after moving/scaling the root or changing
terrain or bake settings. The tool script shows the generated mesh in editor.
Save the scene to retain the exported `bake` resource, or save it externally
under `resources/snow/`. Runtime uses this resource without terrain sampling or
mesh generation. Unbaked scenes retain an automatic runtime bake fallback.
The snow test scene has a prepared external bake.

Add render layer 5 to deforming meshes. Keep terrain and snow off that layer.
Deformation is runtime-only; the editor previews untouched snow.
`deformation_smoothing` sets the contact filter radius in metres and changes
live. Rebaking clears tracks. Large radii are expensive (capped at 16 pixels).

Node references are exported and wired in the prefab. Missing required
references are configuration errors. Terrain3D is sampled read-only.
