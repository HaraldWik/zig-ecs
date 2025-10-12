const std = @import("std");

pub const ecs_lib = struct {
    pub const Entity = enum(usize) {
        _,

        pub fn get(self: @This(), comptime T: type, ecs: anytype) ?T {
            return ecs.getLayoutComp(T).items[@intFromEnum(self)];
        }

        pub fn getPtr(self: @This(), comptime T: type, ecs: anytype) ?*T {
            var val = @field(ecs.layout, @typeName(T)).items[@intFromEnum(self)];
            return if (val != null) &val.? else null;
        }

        pub fn set(self: @This(), comptime T: type, val: T, ecs: anytype) void {
            ecs.getLayoutComp(T).items[@intFromEnum(self)] = val;
        }

        pub fn getGeneration(self: @This(), ecs: anytype) usize {
            return ecs.generation.items[@intFromEnum(self)];
        }
    };

    pub fn Ecs(comps: []const type) type {
        const types: [comps.len]type = types: {
            var types: [comps.len]type = @splat(@TypeOf(null));
            for (comps, &types) |comp, *@"type"| @"type".* = std.ArrayList(comp);
            break :types types;
        };

        const kvs = kvs: {
            var kvs: [comps.len]struct { key: type, value: usize } = undefined;
            for (comps, &kvs, 0..) |comp, *kv, i| kv.* = .{ .key = comp, .value = i };
            break :kvs kvs;
        };

        return struct {
            allocator: std.mem.Allocator,

            layout: Layout = undefined,
            // info: []std.meta.Int(.unsigned, comps.len),
            generation: std.ArrayList(usize) = .empty,
            next: std.Deque(Entity) = .empty,

            pub const Layout: type = std.meta.Tuple(&types);

            pub fn getCompIndex(comptime T: type) usize {
                inline for (kvs) |kv| if (kv.key == T) return kv.value;
                @panic("invalid type of " ++ @typeName(T));
            }

            pub fn init(allocator: std.mem.Allocator, capacity: ?usize) !@This() {
                var self: @This() = .{
                    .allocator = allocator,
                    .generation = try .initCapacity(allocator, capacity orelse 1),
                    .next = try .initCapacity(allocator, 1),
                };
                inline for (comps) |comp| self.layout[comptime getCompIndex(comp)] = try .initCapacity(allocator, capacity orelse 1);
                return self;
            }

            pub fn deinit(self: *@This()) void {
                self.generation.deinit(self.allocator);
                inline for (comps) |comp| self.layout[comptime getCompIndex(comp)].deinit(self.allocator);
            }

            pub fn getLayoutComp(self: @This(), comptime T: type) std.ArrayList(T) {
                return self.layout[comptime getCompIndex(T)];
            }

            pub fn add(self: *@This()) !Entity {
                const front: usize = @intFromEnum(self.next.popFront() orelse @as(Entity, @enumFromInt(self.generation.items.len)));
                try self.generation.insert(self.allocator, front, 0);
                inline for (comps) |comp| try self.layout[comptime getCompIndex(comp)].insert(self.allocator, front, undefined);

                return @enumFromInt(front);
            }

            pub fn remove(self: *@This(), entity: Entity) !void {
                self.generation.items[@intFromEnum(entity)] += 1;
                try self.next.pushFront(self.allocator, entity);
            }

            pub fn query(self: @This(), comptime T: []const type, allocator: std.mem.Allocator) !std.ArrayList(Entity) {
                var len: usize = std.math.maxInt(usize);
                inline for (comps) |comp| len = @min(len, self.getLayoutComp(comp).items.len);

                var out: std.ArrayList(Entity) = try .initCapacity(allocator, 128);

                for (0..len) |i| {
                    var found: usize = 0;
                    inline for (T) |comp| {
                        if (self.getLayoutComp(comp).items[i] != null) found += 1;
                    }

                    if (found == T.len) try out.append(allocator, @enumFromInt(i));
                }

                return out;
            }

            pub fn queryBuffer(self: @This(), comptime T: []const type, buffer: []Entity) !usize {
                @memset(buffer, @enumFromInt(0));

                var len: usize = std.math.maxInt(usize);
                inline for (comps) |comp| len = @min(len, self.getLayoutComp(comp).items.len);

                var out: usize = 0;

                for (0..len) |i| {
                    var found: usize = 0;
                    inline for (T) |comp| {
                        if (self.getLayoutComp(comp).items[i] != 0) found += 1;
                    }

                    if (found == T.len) {
                        out += 1;
                        buffer[i] = @enumFromInt(i);
                    }
                }

                return out;
            }
        };
    }
};

pub const Vec3 = @Vector(3, f32);

pub const Ecs = ecs_lib.Ecs(&.{ u32, f32, Vec3 });

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var ecs: Ecs = try .init(allocator, null);
    defer ecs.deinit();

    const player: ecs_lib.Entity = try ecs.add();
    player.set(u32, 28, ecs);

    const bob: ecs_lib.Entity = try ecs.add();
    bob.set(f32, 33.33, ecs);

    const billy: ecs_lib.Entity = try ecs.add();
    billy.set(f32, 33.33, ecs);

    const harald: ecs_lib.Entity = try ecs.add();
    harald.set(f32, 67.69, ecs);
    try ecs.remove(harald);

    const thing: ecs_lib.Entity = try ecs.add();
    thing.set(u32, 420, ecs);

    std.debug.print("u32: {any}\nf32: {any}\n", .{ ecs.layout[comptime @TypeOf(ecs).getCompIndex(u32)].items, ecs.layout[comptime @TypeOf(ecs).getCompIndex(f32)].items });

    var query: [1028]ecs_lib.Entity = undefined;
    const n = try ecs.queryBuffer(&.{u32}, &query);
    for (query[0..n]) |entity| {
        std.debug.print("Entity: {d}, gen: {d} val: {?}\n", .{ @intFromEnum(entity), entity.getGeneration(ecs), entity.get(u32, ecs) });
    }
}
