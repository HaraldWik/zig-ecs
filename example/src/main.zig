const std = @import("std");
const ecs = @import("ecs");

pub const World = ecs.World(&.{ u32, f32, @Vector(3, f32) });

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var world: World = try .init(allocator, null);
    defer world.deinit();

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
    thing.set(u32, 420, world);

    var query = try world.allocQuery(&.{u32}, allocator);
    defer query.deinit(allocator);
    std.debug.print("Entities: ", .{});
    for (query.items) |entity| {
        std.debug.print("{d}, ", .{@intFromEnum(entity)});
        std.debug.print("{?}, {?}, ", .{ entity.get(f32, world), entity.getPtr(f32, world) });
    }
    std.debug.print("\n", .{});
}
