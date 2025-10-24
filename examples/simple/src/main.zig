const std = @import("std");
const ecs = @import("ecs");

pub const Components: []const type = &.{ u32, u64 };
pub const Components2: []const type = &.{ f32, f64 };

pub const World = ecs.World(ecs.MergeComponentSlices(&.{ Components, Components2 }));

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var world: World = try .init(allocator, null);
    defer world.deinit();

    const player: ecs.Entity = try world.add();
    player.set(u32, 28, world);

    const bob: ecs.Entity = try world.add();
    bob.set(f32, 33.33, world);

    const billy: ecs.Entity = try world.add();
    billy.set(f32, 33.33, world);
    billy.set(u32, 67, world);

    const harald: ecs.Entity = try world.add();
    harald.set(f32, 67.69, world);
    try world.remove(harald);

    const thing: ecs.Entity = try world.add();
    thing.set(f32, 69.123, world);
    thing.set(u32, 420, world);

    try queryEntities(allocator, &world);

    std.debug.print("Total entity count {d}\n", .{world.entity_count});
}

pub fn queryEntities(allocator: std.mem.Allocator, world: *World) !void {
    var query = try world.allocQuery(&.{ u32, f32 }, allocator);
    defer query.deinit(allocator);
    std.debug.print("Entities: ", .{});
    for (query.items) |entity| {
        std.debug.print("(i: {d}, u: {?}, f: {?}, g: {x}), ", .{ @intFromEnum(entity), entity.get(u32, world), entity.get(f32, world), entity.getGeneration(world) });
    }
    std.debug.print("\n", .{});
}
