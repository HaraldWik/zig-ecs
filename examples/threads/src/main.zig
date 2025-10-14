const std = @import("std");
const ecs = @import("ecs");

pub const Vec3 = @Vector(3, f32);
pub const World = ecs.World(&.{Vec3});

pub fn addPlayer(world: *World) !void {
    std.debug.print("len {d} ", .{world.entity_count});
    for (0..10) |_| {
        const player: ecs.Entity = try world.*.add();
        player.set(Vec3, .{ 0, 1, 2 }, world.*);
    }
    std.debug.print("→ {d}\n", .{world.entity_count});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var world: World = try .init(allocator, null);
    defer world.deinit();

    const player: ecs.Entity = try world.add();
    player.set(Vec3, .{ 0, 1, 2 }, world);

    var threads: [5]std.Thread = undefined;
    for (&threads) |*thread| thread.* = try .spawn(.{}, addPlayer, .{&world});
    defer for (threads) |thread| thread.join();

    var query = try world.allocQuery(&.{Vec3}, allocator);
    defer query.deinit(allocator);
    std.debug.print("Entities: ", .{});
    for (query.items) |entity| {
        std.debug.print("{d}, ", .{@intFromEnum(entity)});
    }
    std.debug.print("\n", .{});

    std.debug.print("Total entity count {d}\n", .{world.entity_count});
}
