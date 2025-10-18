const std = @import("std");
const ecs = @import("ecs");

pub const Default = ecs.DefaultWorld(&.{ u32, f32 });

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var default: Default = try .init(allocator, null);
    defer default.deinit();

    const world: ecs.World(Default) = default.world();

    const player: ecs.Entity = try world.add();
    player.set(u32, 28, world);

    const bob: ecs.Entity = try world.add();
    bob.set(f32, 33.33, world);

    const billy: ecs.Entity = try world.add();
    billy.set(f32, 33.33, world);

    const harald: ecs.Entity = try world.add();
    harald.set(f32, 67.69, world);
    try world.remove(harald);

    const thing: ecs.Entity = try world.add();
    thing.set(f32, 69.123, world);
    thing.set(u32, 420, world);

    var query = try world.allocQuery(&.{ u32, f32 }, allocator);
    defer query.deinit(allocator);
    std.debug.print("Entities: ", .{});
    for (query.items) |entity| {
        std.debug.print("(i: {d}, u: {any}, f: {?}), ", .{ @intFromEnum(entity), entity.getPtr(u32, world), entity.get(f32, world) });
    }
    std.debug.print("\n", .{});

    std.debug.print("Total entity count {d}\n", .{world.getEntityCount()});
}
