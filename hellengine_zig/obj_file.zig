const std = @import("std");
const engine = @import("../engine.zig");
const resources = @import("resources.zig");
const Geometry = resources.Geometry;
const GeometryConfig = resources.GeometryConfig;
const MaterialCreateInfo = resources.MaterialCreateInfo;
const MaterialInfo = resources.MaterialInfo;
const Logger = resources.Logger;
const Vertex = engine.resources.Vertex;

const ResourceHandle = engine.core.ResourceHandle;

/// offsets start at 1, not 0
pub const ObjFace = struct {
    position_offset: u32,
    normal_offset: u32,
    uv_offset: u32,
};


pub const ObjFileParseState = struct {

    allocator: std.mem.Allocator,

    positions: std.ArrayList([3]f32),
    normals:   std.ArrayList([3]f32),
    uvs:       std.ArrayList([2]f32),
    faces:     std.ArrayList(ObjFace),

    material_name: [512]u8,
    material_name_len: usize,

    pub fn init(allocator: std.mem.Allocator) ObjFileParseState {
        return ObjFileParseState {
            .allocator = allocator,
            .positions = std.ArrayList([3]f32) .init(allocator),
            .normals   = std.ArrayList([3]f32) .init(allocator),
            .uvs       = std.ArrayList([2]f32) .init(allocator),
            .faces     = std.ArrayList(ObjFace).init(allocator),
            .material_name     = undefined, // @Todo
            .material_name_len = 0,
        };
    }

    pub fn deinit(self: *ObjFileParseState) void {
        self.positions.deinit();
        self.normals.deinit();
        self.uvs.deinit();
        self.faces.deinit();
    }
};

// ----------------------------------------------------------------------------

pub const ObjFileParseResult = struct {
    pub const MatlibPath = engine.core.StackArray(u8, 512);
    pub const GeometryConfigList = std.ArrayList(GeometryConfig);

    geometry_configs: GeometryConfigList,
    matlib_path:      ?MatlibPath = null,

    pub fn init(allocator: std.mem.Allocator) ObjFileParseResult {
        return ObjFileParseResult {
            .geometry_configs = GeometryConfigList.init(allocator),
            .matlib_path      = null,
        };
    }
    pub fn deinit(self: *ObjFileParseResult) void {
        self.geometry_configs.deinit();
    }
};

// ----------------------------------------------------------------------------

pub const ObjMaterialFileParseResult = struct {
    create_infos: MaterialCreateInfo.List,

    pub fn init(allocator: std.mem.Allocator) ObjMaterialFileParseResult {
        return ObjMaterialFileParseResult {
            .create_infos = MaterialCreateInfo.List.init(allocator),
        };
    }

    pub fn deinit(self: *ObjMaterialFileParseResult) void {
        self.create_infos.deinit();
    }
};

// ----------------------------------------------------------------------------

pub const ObjFileLoader = struct {
    pub fn parse_obj_file(allocator: std.mem.Allocator, reader: anytype, result: *ObjFileParseResult) !void {
        Logger.info("parsing obj file\n", .{});

        var line_buffer: [1024]u8 = undefined;

        var state = ObjFileParseState.init(allocator);
        defer state.deinit();

        // var geometry_configs = std.ArrayList(GeometryConfig).init(allocator);

        while(try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |raw_line| {
            const line = std.mem.trimLeft(u8, raw_line, " \t");

            if (line.len == 0)  { continue; }
            if (line[0] == '#') { continue; }

            var splits = std.mem.tokenize(u8, line, " ");
            const op = splits.next().?;

            // groups
            if (std.mem.eql(u8, op, "g")) {
                const group_name = splits.next().?;
                Logger.debug("[OBJ] group: '{s}'\n", .{group_name});

                if (state.faces.items.len > 0) {
                    try result.geometry_configs.append(try ObjFileLoader.create_geometry_config_from_group(&state));
                    state.faces.clearRetainingCapacity();
                }
            }
            // positions coordinates
            else if (std.mem.eql(u8, op, "v")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                const z = try std.fmt.parseFloat(f32, splits.next().?);
                try state.positions.append([_]f32 { x, y, z });
            }
            // texture coordinates
            else if (std.mem.eql(u8, op, "vt")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                try state.uvs.append([_]f32 { x, y });
            }
            // normals
            else if (std.mem.eql(u8, op, "vn")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                const z = try std.fmt.parseFloat(f32, splits.next().?);
                try state.normals.append([_]f32 { x, y, z });
            }
            // faces
            else if (std.mem.eql(u8, op, "f")) {
                // @Todo: triangulate ngons
                const face_1 = try ObjFileLoader.parse_obj_face(splits.next().?);
                const face_2 = try ObjFileLoader.parse_obj_face(splits.next().?);
                const face_3 = try ObjFileLoader.parse_obj_face(splits.next().?);
                try state.faces.appendSlice(&[_]ObjFace {face_1, face_2, face_3});
            }
            // material uses
            else if (std.mem.eql(u8, op, "usemtl")) {
                const mat_name = splits.next().?;
                std.debug.assert(mat_name.len < state.material_name.len);
                @memcpy(state.material_name[0..mat_name.len], mat_name);
                state.material_name_len = mat_name.len;
            }
            // material lib
            else if (std.mem.eql(u8, op, "mtllib")) {
                const mat_name = splits.next().?;
                result.matlib_path = ObjFileParseResult.MatlibPath.from_slice(mat_name);
            }
            else {
                Logger.warn("ignoring unknown operation in obj-file '{s}'\n", .{op});
                continue;
            }
        }

        // create a mesh from the current state
        if (state.positions.items.len > 0) {
            try result.geometry_configs.append(try ObjFileLoader.create_geometry_config_from_group(&state));
        }

        std.debug.assert(result.geometry_configs.items.len > 0);
        Logger.info("read '{}' geometry configs from obj file\n", .{result.geometry_configs.items.len});
    }

    fn parse_obj_face(face_str: []const u8) !ObjFace {
        var split = std.mem.tokenize(u8, face_str, "/");
        const position_offset = try std.fmt.parseInt(u32, split.next().?, 10);
        const uv_offset       = try std.fmt.parseInt(u32, split.next().?, 10);
        const normal_offset   = try std.fmt.parseInt(u32, split.next().?, 10);

        return ObjFace {
            .position_offset = position_offset,
            .uv_offset       = uv_offset,
            .normal_offset   = normal_offset,
        };
    }

    fn create_geometry_config_from_group(state: *ObjFileParseState) !GeometryConfig {
        var vertices = std.ArrayList(Vertex).init(state.allocator);
        var indices  = try std.ArrayList(u32).initCapacity(state.allocator, state.faces.items.len);
        std.debug.assert(state.faces.items.len > 0);

        for (state.faces.items) |face| {
            const new_index: u32 = @intCast(vertices.items.len);

            try vertices.append(Vertex {
                .position = state.positions.items[face.position_offset - 1],
                .normal   = state.normals  .items[face.normal_offset   - 1],
                .uv       = state.uvs      .items[face.uv_offset       - 1],
            });

            try indices.append(new_index);
        }

        return GeometryConfig {
            .vertices = try vertices.toOwnedSlice(),
            .indices  = try indices .toOwnedSlice(),

            .material_name = state.material_name,
            .material_name_len = state.material_name_len,
        };
    }

    pub fn parse_obj_material_file(allocator: std.mem.Allocator, reader: anytype, result: *ObjMaterialFileParseResult, base_path: []const u8) !void {
        Logger.info("parsing obj material file\n", .{});

        var line_buffer: [1024]u8 = undefined;

        var state = ObjFileParseState.init(allocator);
        defer state.deinit();
        var curr_create_info: ?*MaterialCreateInfo = null;

        while(try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |raw_line| {
            const line = std.mem.trimLeft(u8, raw_line, " \t");

            if (line.len == 0)  { continue; }
            if (line[0] == '#') { continue; }

            var splits = std.mem.tokenize(u8, line, " ");
            const op = splits.next().?;

            // new material
            if (std.mem.eql(u8, op, "newmtl")) {
                const mat_name = splits.next().?;
                Logger.debug("[OBJ] newmtl: '{s}'\n", .{mat_name});

                try result.create_infos.append(MaterialCreateInfo {
                    .info = MaterialInfo {
                        .name = MaterialInfo.MaterialName.from_slice_with_zero_terminator(mat_name),
                    },
                });
                curr_create_info = &result.create_infos.items[result.create_infos.items.len - 1];
            }
            // ambient color
            else if (std.mem.eql(u8, op, "Ka")) {
                curr_create_info.?.info.ambient_color = .{
                    try std.fmt.parseFloat(f32, splits.next().?),
                    try std.fmt.parseFloat(f32, splits.next().?),
                    try std.fmt.parseFloat(f32, splits.next().?),
                };
            }
            // diffuse color
            else if (std.mem.eql(u8, op, "Kd")) {
                curr_create_info.?.info.diffuse_color = .{
                    try std.fmt.parseFloat(f32, splits.next().?),
                    try std.fmt.parseFloat(f32, splits.next().?),
                    try std.fmt.parseFloat(f32, splits.next().?),
                };
            }
            // specular color
            else if (std.mem.eql(u8, op, "Ks")) {
                curr_create_info.?.info.specular_color = .{
                    try std.fmt.parseFloat(f32, splits.next().?),
                    try std.fmt.parseFloat(f32, splits.next().?),
                    try std.fmt.parseFloat(f32, splits.next().?),
                };
            }
            // specular exponent
            else if (std.mem.eql(u8, op, "Ns")) {
                curr_create_info.?.info.specular_exponent = try std.fmt.parseFloat(f32, splits.next().?);
            }
            // dissolve
            else if (std.mem.eql(u8, op, "d")) {
                curr_create_info.?.info.alpha = try std.fmt.parseFloat(f32, splits.next().?);
            }
            // transparency
            else if (std.mem.eql(u8, op, "Tr")) {
                curr_create_info.?.info.alpha = 1.0 - try std.fmt.parseFloat(f32, splits.next().?);
            }
            // transmission filter
            else if (std.mem.eql(u8, op, "Tf")) {
                Logger.warn("Transmission filter 'Tf' are not supported", .{});
            }
            // optical density
            else if (std.mem.eql(u8, op, "Ni")) {
                curr_create_info.?.info.refraction_index = try std.fmt.parseFloat(f32, splits.next().?);
            }
            // illumination model
            else if (std.mem.eql(u8, op, "illum")) {
                const raw = try std.fmt.parseInt(u8, splits.next().?, 10);
                curr_create_info.?.info.illumination_model = @enumFromInt(raw);
            }
            // ambient color map
            else if (std.mem.eql(u8, op, "map_Ka")) {
                curr_create_info.?.ambient_color_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // diffuse color map
            else if (std.mem.eql(u8, op, "map_Kd")) {
                curr_create_info.?.diffuse_color_map  = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // specular color map
            else if (std.mem.eql(u8, op, "map_Kd")) {
                curr_create_info.?.specular_color_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // specular highlight map
            else if (std.mem.eql(u8, op, "map_Ns")) {
                curr_create_info.?.specular_highlight_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // disolve map
            else if (std.mem.eql(u8, op, "map_d")) {
                curr_create_info.?.alpha_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // bump map
            else if (std.mem.eql(u8, op, "map_bump") or std.mem.eql(u8, op, "bump")) {
                curr_create_info.?.bump_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // displacement map
            else if (std.mem.eql(u8, op, "map_disp")) {
                curr_create_info.?.displacement_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            // decal map
            else if (std.mem.eql(u8, op, "decal")) {
                curr_create_info.?.stencil_decal_map = MaterialInfo.MaterialName.from_slices_with_zero_terminator(&.{base_path,  "/", splits.next().?});
            }
            else {
                Logger.warn("ignoring unknown operation in obj-matlib-file '{s}'\n", .{op});
                continue;
            }
        }

        std.debug.assert(result.create_infos.items.len > 0);
        Logger.info("read '{}' material create-infos from obj file\n", .{result.create_infos.items.len});
    }
};

