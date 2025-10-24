const std = @import("std");
const ecs = @import("ecs");

pub const Components1: []const type = &.{ u32, u64 };
pub const Components2: []const type = &.{ f32, f64 };

pub const World = ecs.World(ecs.MergeComponentSlices(&.{ Components1, Components2 }));

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .safety = true }) = .{};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var world: World = try .init(allocator, null);
    defer world.deinit();

    for (0..10) |i| {
        const thing: ecs.Entity = try world.add();
        thing.set(f32, @floatFromInt(i), world);
    }

    for (0..10) |i| {
        const player: ecs.Entity = try world.add();
        player.set(f32, @floatFromInt(i * 20), world);
        player.set(u32, @intCast(1), world);
    }

    for (0..10) |i| {
        const thing: ecs.Entity = try world.add();
        thing.set(u32, @intCast(i), world);
    }

    try query(&world);

    std.debug.print("Total entity count {d}\n", .{world.entity_count});
}

pub fn query(world: *World) !void {
    var it = world.query(&.{ u32, f32 });
    std.debug.print("Entities: \n", .{});
    while (it.next()) |entity| {
        if (entity.getPtr(u32, world)) |num| num.* += 1;
        if (entity.getPtr(f32, world)) |num| num.* += 3;

        std.debug.print("{d}: u32: {?}, f32: {?}\n", .{ @intFromEnum(entity) + 1, entity.get(u32, world), entity.get(f32, world) });
    }
    std.debug.print("\n", .{});
}
