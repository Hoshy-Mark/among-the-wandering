extends "res://personagem/personagem.gd"
## Dedicated geometry/catalog, with the same rig and articulation pipeline.
func _json(path: String) -> Dictionary:
    if path=="catalogo.json":return JSON.parse_string(FileAccess.get_file_as_string(base_dir+"catalogo_feminino106.json"))
    if path=="roupas.json":return JSON.parse_string(FileAccess.get_file_as_string(base_dir+"roupas_femininas106.json"))
    return super._json(path)

func _body_mask(flags: int) -> ArrayMesh:
    if body_masks.has(flags):return body_masks[flags]
    var path=base_dir+"assets/female106/masks/corpo_%d.res"%flags
    if ResourceLoader.exists(path):body_masks[flags]=load(path);return body_masks[flags]
    if segmented_body==null:
        var donor: Node3D=load(base_dir+str(clothing.body_mask_source)).instantiate()
        for mesh in _all_meshes(donor):
            if "CABECA_E_CORPO" in str(mesh.name):segmented_body=mesh.mesh
        donor.free()
    var result=ArrayMesh.new();result.blend_shape_mode=segmented_body.blend_shape_mode
    for i in segmented_body.get_blend_shape_count():result.add_blend_shape(segmented_body.get_blend_shape_name(i))
    for surface in segmented_body.get_surface_count():
        var arrays=segmented_body.surface_get_arrays(surface)
        var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
        var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
        if indices.is_empty():
            for i in positions.size():indices.append(i)
        var kept=PackedInt32Array()
        for triangle in range(0,indices.size(),3):
            var center=(positions[indices[triangle]]+positions[indices[triangle+1]]+positions[indices[triangle+2]])/3
            if (_triangle_coverage(center)&flags)!=0:continue
            kept.append_array(indices.slice(triangle,triangle+3))
        if kept.is_empty():continue
        arrays[Mesh.ARRAY_INDEX]=kept
        result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,segmented_body.surface_get_blend_shape_arrays(surface))
        result.surface_set_material(result.get_surface_count()-1,segmented_body.surface_get_material(surface))
    body_masks[flags]=result;return result

func appearance_report() -> Dictionary:
    return {"schema":"ea.character.appearance.v2","base":"female106","selection":selection.duplicate(true)}

func load_report(report: Variant) -> bool:
    if not report is Dictionary or report.get("base")!="female106" or report.get("schema")!="ea.character.appearance.v2" or not report.get("selection") is Dictionary:return false
    return set_appearance(report.selection)
