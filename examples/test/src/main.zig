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
        thing.set(u32, @intCast(i * 2), world);
    }

    for (0..10) |i| {
        const thing: ecs.Entity = try world.add();
        thing.set(f32, @floatFromInt(i), world);
    }

    try query(&world);
}

pub fn query(world: *World) !void {
    var it = world.query(&.{f32});
    std.debug.print("Entities: \n", .{});
    while (it.next()) |entity| {
        if (entity.getPtr(f32, world)) |num| num.* += 1;

        std.debug.print("{d:2}, f32: {?:2}\n", .{ @intFromEnum(entity) + 1, entity.get(f32, world) });
    }
    std.debug.print("\n", .{});
}
