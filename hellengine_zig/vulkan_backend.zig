const std    = @import("std");
const assert = std.debug.assert;

const vk     = @import("vulkan");
const CFG    = @import("../../config.zig");

const core           = @import("../../core/core.zig");
const ResourceHandle = core.ResourceHandle;

const engine     = @import("../../engine.zig");
const render     = engine.render;
const ShaderInfo = render.ShaderInfo;

const vulkan          = @import("./vulkan.zig");
const Logger          = vulkan.Logger;
const ShaderInternals = vulkan.ShaderInternals;

const ShaderProgram   = render.ShaderProgram;
const ShaderScope     = render.shader.ShaderScope;

// ...

// ----------------------------------------------

const BUFFER_BINDING_IDX        = 0;
const IMAGE_SAMPLER_BINDING_IDX = 1;
const UNIFORM_SCOPES       = [_]ShaderScope { .global, .material };
const STORAGE_SCOPES       = [_]ShaderScope { .scene };
const PUSH_CONSTANT_SCOPES = [_]ShaderScope { .object };

// ----------------------------------------------

const DescriptorSetLayoutBindingStack = core.StackArray(vk.DescriptorSetLayoutBinding, 2);
const DescriptorImageInfoStack        = core.StackArray(vk.DescriptorImageInfo, CFG.max_uniform_samplers_per_shader);
const PushConstantRangeStack          = core.StackArray(vk.PushConstantRange,   CFG.vulkan_push_constant_stack_limit);

// ----------------------------------------------

const SCOPE_SET_INDICES = [_]usize { 0, 1, 2, 3 };
pub inline fn scope_set_index(scope: ShaderScope) usize {
    return SCOPE_SET_INDICES[@intFromEnum(scope)];
}

// ----------------------------------------------

// ...

pub const VulkanBackend = struct {

    // ...

    vkb: vulkan.BaseDispatch     = undefined,
    vki: vulkan.InstanceDispatch = undefined,
    vkd: vulkan.DeviceDispatch   = undefined,

    physical_device: vk.PhysicalDevice = .null_handle,
    device: vk.Device = .null_handle,

    render_pass: vk.RenderPass = .null_handle,

    // ...

    pub fn create_shader_internals(self: *VulkanBackend, info: *const ShaderInfo, internals: *ShaderInternals) !void {
        Logger.debug("creating shader-program\n", .{});

        // TODO(lm):
        // errdefer self.destroy_shader_internals(&internals);

        // create attributes
        {
            var attr_stride: usize = 0;

            for (info.attributes.as_slice()) |attr| {
                internals.attributes.push(.{
                    .binding  = @intCast(attr.binding),
                    .location = @intCast(attr.location),
                    .format   = attr.format.to_vk_format(),
                    .offset   = @intCast(attr_stride),
                });

                attr_stride += attr.format.size();
            }
        }

        // create uniform-buffer
        // TODO(lm): compress uniform- and storage-buffer creation
        {
            for (UNIFORM_SCOPES) |scopes| {
                const scope_idx     = @intFromEnum(scopes);
                const scope_info    = info.scopes[scope_idx];
                var scope_internals = &internals.scopes[scope_idx];

                scope_internals.buffer_offset = internals.uniform_buffer_total_size_aligned;
                scope_internals.buffer_descriptor_type = .uniform_buffer;

                for (scope_info.buffers.as_slice()) |buff| {
                    scope_internals.buffer_instance_size_unalinged += buff.size;
                }

                // align buffer-instance-size
                while (scope_internals.buffer_instance_size_alinged < scope_internals.buffer_instance_size_unalinged) {
                    scope_internals.buffer_instance_size_alinged += CFG.vulkan_ubo_alignment;
                }

                internals.uniform_buffer_total_size_aligned += scope_internals.buffer_instance_size_alinged * scope_info.instance_count;
            }

            Logger.debug("total uniform-buffer size: {} byte\n", .{internals.uniform_buffer_total_size_aligned});

            if (internals.uniform_buffer_total_size_aligned > 0) {
                const buffer_h                   = try self.create_uniform_buffer(internals.uniform_buffer_total_size_aligned);
                internals.uniform_buffer         = self.get_buffer(buffer_h);
                internals.uniform_buffer_mapping = @as([*]u8, @ptrCast(
                    try self.vkd.mapMemory(self.device, internals.uniform_buffer.mem, 0, internals.uniform_buffer_total_size_aligned, .{}),
                ))[0..internals.uniform_buffer_total_size_aligned];
            }
        }

        // create storage-buffer
        {
            for (STORAGE_SCOPES) |scope| {
                const scope_idx     = @intFromEnum(scope);
                const scope_info    = info.scopes[scope_idx];
                var scope_internals = &internals.scopes[scope_idx];

                scope_internals.buffer_offset = internals.storage_buffer_total_size_aligned;
                scope_internals.buffer_descriptor_type = .storage_buffer;

                for (scope_info.buffers.as_slice()) |buff| {
                    scope_internals.buffer_instance_size_unalinged += buff.size;
                }

                // align buffer-instance-size
                while (scope_internals.buffer_instance_size_alinged < scope_internals.buffer_instance_size_unalinged) {
                    scope_internals.buffer_instance_size_alinged += CFG.vulkan_ubo_alignment;
                }

                internals.storage_buffer_total_size_aligned = scope_internals.buffer_instance_size_alinged * scope_info.instance_count;
            }


            Logger.debug("total storage-buffer size: {} byte\n", .{internals.storage_buffer_total_size_aligned});

            // TODO(lm): consider making 'storage_buffer' nullable
            if (internals.storage_buffer_total_size_aligned > 0) {
                const buffer_h = try self.create_storage_buffer(internals.storage_buffer_total_size_aligned);
                internals.storage_buffer = self.get_buffer(buffer_h);
                internals.storage_buffer_mapping = @as([*]u8, @ptrCast(
                    try self.vkd.mapMemory(self.device, internals.storage_buffer.mem, 0, internals.storage_buffer_total_size_aligned, .{}),
                ))[0..internals.storage_buffer_total_size_aligned];
            }
        }

        // create descriptor-sets
        {
            internals.descriptor_pool = try self.create_descriptor_pool();

            for (info.scopes, 0..) |scope_info, idx| {
                // create layout
                // -------------
                var bindings = DescriptorSetLayoutBindingStack{};
                var scope_internals = &internals.scopes[idx];

                if (!scope_info.buffers.is_empty()) {
                    // TODO(lm): make configurable
                    if (idx != @intFromEnum(ShaderScope.scene) and idx != @intFromEnum(ShaderScope.object)) {
                        Logger.debug("add uniform-buffer to scope {} at binding {}\n", .{idx, BUFFER_BINDING_IDX});

                        // use uniform-buffers for non-object scopes
                        bindings.push(.{
                            .binding = BUFFER_BINDING_IDX,
                            .descriptor_count = 1,
                            .descriptor_type = .uniform_buffer,
                            .p_immutable_samplers = null,
                            .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
                        });
                    }
                    else {
                        Logger.debug("add storage-buffer to scope {} at binding {}\n", .{idx, BUFFER_BINDING_IDX});

                        // use storage-buffers for object scope
                        bindings.push(.{
                            .binding = BUFFER_BINDING_IDX,
                            .descriptor_count = 1,
                            .descriptor_type = .storage_buffer,
                            .p_immutable_samplers = null,
                            .stage_flags = .{ .vertex_bit = true, .fragment_bit = true },
                        });
                    }
                }

                if (!scope_info.samplers.is_empty()) {
                    Logger.debug("add sampler-layout to scope {} at binding {} with {} samplers\n", .{idx, IMAGE_SAMPLER_BINDING_IDX, scope_info.samplers.len});
                    bindings.push(.{
                        .binding = IMAGE_SAMPLER_BINDING_IDX,
                        .descriptor_count = @as(u32, @intCast(scope_info.samplers.len)),
                        .descriptor_type = .combined_image_sampler,
                        .p_immutable_samplers = null,
                        .stage_flags = .{ .fragment_bit = true },
                    });
                }

                // NOTE(lm): when there are no bindings, we are still creating an empty set, so that we don't have to use dynamic set indices
                //           -> set 0 is always 'global', set 3 is always 'object'
                const layout_info = vk.DescriptorSetLayoutCreateInfo {
                    .flags         = .{},
                    .binding_count = @as(u32, @intCast(bindings.len)),
                    .p_bindings    = if (bindings.is_empty()) null else &bindings.items_raw,
                };

                scope_internals.descriptor_set_layout = try self.vkd.createDescriptorSetLayout(self.device, &layout_info, null);
            }
        }

        // add push constants
        {
            for (PUSH_CONSTANT_SCOPES) |scope| {
                const scope_idx  = @intFromEnum(scope);
                const scope_info = &info.scopes[scope_idx];

                for (scope_info.buffers.as_slice()) |scope_buffer| {
                    Logger.debug("add push constant '{s}' with size '{}' to scope '{}'\n", .{scope_buffer.name.as_slice(), scope_buffer.size, scope});

                    const range = core.utils.get_aligned_range(0, scope_buffer.size, CFG.vulkan_push_constant_alignment);
                    internals.push_constant_internals.push(.{
                        .range = range,
                    });
                }
            }
        }

        var all_layouts: [4]vk.DescriptorSetLayout = undefined;
        inline for (0..4) |idx| {
            all_layouts[idx] = internals.scopes[idx].descriptor_set_layout;
        }

        internals.pipeline = try self.create_graphics_pipeline(
            self.render_pass,
            all_layouts[0..],
            internals.attributes.as_slice(),
            internals.push_constant_internals.as_slice());
    }

    pub fn destroy_shader_internals(self: *VulkanBackend, internals: *ShaderInternals) void {
        Logger.debug("destroying shader-internals\n", .{});

        for (internals.scopes) |scope| {
            if (scope.descriptor_set_layout != .null_handle) {
                self.vkd.destroyDescriptorSetLayout(self.device, scope.descriptor_set_layout, null);
            }
        }

        if (internals.descriptor_pool != .null_handle) self.vkd.destroyDescriptorPool(self.device, internals.descriptor_pool, null);

        // cleanup uniform buffer
        self.vkd.unmapMemory(self.device, internals.uniform_buffer.mem);
        internals.uniform_buffer_mapping = undefined;
        self.free_buffer(internals.uniform_buffer);

        // cleanup storage buffer
        self.vkd.unmapMemory(self.device, internals.storage_buffer.mem);
        internals.storage_buffer_mapping = undefined;
        self.free_buffer(internals.storage_buffer);

        self.destroy_graphics_pipeline(&internals.pipeline);
    }

    pub fn get_shader_internals(self: *VulkanBackend, internals_h: ResourceHandle) *ShaderInternals {
        return self.internals.get_mut(internals_h.value).*;
    }

    // ...
};
