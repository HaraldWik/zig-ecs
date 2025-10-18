const std = @import("std");

pub const Entity = enum(usize) {
    _,

    pub fn get(self: @This(), comptime T: type, world: anytype) ?T {
        return if (world.signatures.items[@intFromEnum(self)] >> @intCast(@TypeOf(world).getCompIndex(T)) == 1)
            world.getLayoutComp(T).items[@intFromEnum(self)]
        else
            null;
    }

    pub fn getPtr(self: @This(), comptime T: type, world: anytype) ?*T {
        var val: ?T = if (world.signatures.items[@intFromEnum(self)] >> @intCast(@TypeOf(world).getCompIndex(T)) == 1)
            world.getLayoutComp(T).items[@intFromEnum(self)]
        else
            null;
        return if (val != null) &val.? else null;
    }

    pub fn set(self: @This(), comptime T: type, val: T, world: anytype) void {
        world.signatures.items[@intFromEnum(self)] |= (@as(@TypeOf(world).Signature, 1) << @intCast(@TypeOf(world).getCompIndex(T)));
        world.getLayoutComp(T).items[@intFromEnum(self)] = val;
    }

    pub fn getSignature(self: @This(), world: anytype) @TypeOf(world).Signature {
        return world.signatures.items[@intFromEnum(self)];
    }

    pub fn getGeneration(self: @This(), world: anytype) usize {
        return world.generation.items[@intFromEnum(self)];
    }
};

pub fn World(comps: []const type) type {
    const types: [comps.len]type = types: {
        var types: [comps.len]type = @splat(@TypeOf(null));
        for (comps, &types) |Comp, *Type| Type.* = std.ArrayList(Comp);
        break :types types;
    };

    const kvs = kvs: {
        var kvs: [comps.len]struct { key: type, value: usize } = undefined;
        for (comps, &kvs, 0..) |Comp, *kv, i| kv.* = .{ .key = Comp, .value = i };
        break :kvs kvs;
    };

    return struct {
        allocator: std.mem.Allocator,

        next: std.Deque(Entity) = .empty,

        layout: Layout = undefined,
        entity_count: usize = 0,
        signatures: std.ArrayList(Signature) = .empty,
        generation: std.ArrayList(usize) = .empty,

        pub const Layout: type = std.meta.Tuple(&types);
        pub const Signature: type = std.meta.Int(.unsigned, comps.len);

        pub fn getCompIndex(comptime T: type) usize {
            inline for (kvs) |kv| if (kv.key == T) return kv.value;
            @panic("invalid type of " ++ @typeName(T));
        }

        pub fn init(allocator: std.mem.Allocator, capacity: ?usize) !@This() {
            var self: @This() = .{
                .allocator = allocator,
                .generation = try .initCapacity(allocator, capacity orelse 1),
            };
            inline for (comps) |Comp| self.layout[comptime getCompIndex(Comp)] = try .initCapacity(allocator, capacity orelse 1);
            return self;
        }

        pub fn deinit(self: *@This()) void {
            self.next.deinit(self.allocator);
            self.generation.deinit(self.allocator);
            inline for (comps) |comp| self.layout[comptime getCompIndex(comp)].deinit(self.allocator);
        }

        pub fn getLayoutComp(self: @This(), comptime T: type) std.ArrayList(T) {
            return self.layout[comptime getCompIndex(T)];
        }

        pub fn add(self: *@This()) !Entity {
            const front: usize = @intFromEnum(self.next.popFront() orelse @as(Entity, @enumFromInt(self.generation.items.len)));
            inline for (comps) |Comp| try self.layout[comptime getCompIndex(Comp)].insert(self.allocator, front, undefined);
            try self.signatures.insert(self.allocator, front, 0);
            try self.generation.insert(self.allocator, front, 0);

            self.entity_count += 1;

            return @enumFromInt(front);
        }

        pub fn remove(self: *@This(), entity: Entity) !void {
            self.generation.items[@intFromEnum(entity)] += 1;
            try self.next.pushFront(self.allocator, entity);

            self.entity_count -= 1;
        }

        pub fn allocQuery(self: @This(), comptime T: []const type, allocator: std.mem.Allocator) !std.ArrayList(Entity) {
            var len: usize = std.math.maxInt(usize);
            inline for (comps) |Comp| len = @min(len, self.getLayoutComp(Comp).items.len);

            var out: std.ArrayList(Entity) = try .initCapacity(allocator, 128);

            for (0..len) |i| {
                var found: usize = 0;

                inline for (T) |Comp| {
                    if (((self.signatures.items[i] >> @intCast(getCompIndex(Comp))) & 1) == 1) found += 1;
                }

                if (found == T.len) try out.append(allocator, @enumFromInt(i));
            }

            return out;
        }

        pub fn bufQuery(self: @This(), comptime T: []const type, buffer: []Entity) !usize {
            @memset(buffer, @enumFromInt(0));

            var len: usize = std.math.maxInt(usize);
            inline for (comps) |Comp| len = @min(len, self.getLayoutComp(Comp).items.len);

            var out: usize = 0;

            for (0..len) |i| {
                var found: usize = 0;
                inline for (T) |Comp| {
                    if (self.signatures.items[i].mask >> @intCast(getCompIndex(Comp)) == 1) found += 1;
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
