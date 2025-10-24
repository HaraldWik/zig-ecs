const std = @import("std");

pub const Entity = enum(usize) {
    _,

    pub fn get(self: @This(), comptime T: type, world: anytype) ?T {
        return world.entityGet(T, self);
    }

    pub fn getPtr(self: @This(), comptime T: type, world: anytype) ?*T {
        return world.entityGetPtr(T, self);
    }

    pub fn set(self: @This(), comptime T: type, val: T, world: anytype) void {
        world.entitySet(T, val, self);
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

        pub const components: []const type = comps;
        pub const Layout: type = std.meta.Tuple(&types);
        pub const Signature: type = std.meta.Int(.unsigned, comps.len);

        pub fn QueryIterator(search: []const type) type {
            return struct {
                world: *World(comps),
                index: usize,
                end: usize,

                pub fn next(self: *@This()) ?Entity {
                    return while (true) {
                        if (self.index >= self.end) return null;

                        self.index += 1;
                        if (self.peek()) |entity| return entity;
                    };
                }

                pub fn peek(self: @This()) ?Entity {
                    if (self.index >= self.end) return null;
                    var found: usize = 0;
                    inline for (search) |Comp| {
                        if (((self.world.signatures.items[self.index] >> @intCast(getCompIndex(Comp))) & 1) == 1) found += 1;
                    }

                    return if (found == search.len) @enumFromInt(self.index) else null;
                }

                pub fn reset(self: *@This()) void {
                    self.index = 0;
                }
            };
        }

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
            self.signatures.deinit(self.allocator);
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

        pub fn allocQuery(self: @This(), comptime search: []const type, allocator: std.mem.Allocator) !std.ArrayList(Entity) {
            var len: usize = std.math.maxInt(usize);
            inline for (comps) |Comp| len = @min(len, self.getLayoutComp(Comp).items.len);

            var out: std.ArrayList(Entity) = try .initCapacity(allocator, 128);

            for (0..len) |i| {
                var found: usize = 0;

                inline for (search) |Comp| {
                    if (((self.signatures.items[i] >> @intCast(getCompIndex(Comp))) & 1) == 1) found += 1;
                }

                if (found == search.len) try out.append(allocator, @enumFromInt(i));
            }

            return out;
        }

        pub fn bufQuery(self: @This(), comptime search: []const type, buffer: []Entity) !usize {
            @memset(buffer, @enumFromInt(0));

            var len: usize = std.math.maxInt(usize);
            inline for (comps) |Comp| len = @min(len, self.getLayoutComp(Comp).items.len);

            var out: usize = 0;

            for (0..len) |i| {
                var found: usize = 0;
                inline for (search) |Comp| {
                    if (((self.signatures.items[i] >> @intCast(getCompIndex(Comp))) & 1) == 1) found += 1;
                }

                if (found == search.len) {
                    out += 1;
                    buffer[i] = @enumFromInt(i);
                }
            }

            return out;
        }

        pub fn query(self: *@This(), comptime search: []const type) QueryIterator(search) {
            var len: usize = std.math.maxInt(usize);
            inline for (comps) |Comp| len = @min(len, self.getLayoutComp(Comp).items.len);

            return QueryIterator(search){
                .world = self,
                .index = 0,
                .end = len,
            };
        }

        pub fn entityGet(self: @This(), comptime T: type, entity: Entity) ?T {
            return if (((self.signatures.items[@intFromEnum(entity)] >> @intCast(getCompIndex(T))) & 1) == 1)
                self.getLayoutComp(T).items[@intFromEnum(entity)]
            else
                null;
        }

        pub fn entityGetPtr(self: @This(), comptime T: type, entity: Entity) ?*T {
            return if (((self.signatures.items[@intFromEnum(entity)] >> @intCast(getCompIndex(T))) & 1) == 1)
                &self.getLayoutComp(T).items[@intFromEnum(entity)]
            else
                null;
        }

        pub fn entitySet(self: @This(), comptime T: type, val: T, entity: Entity) void {
            self.signatures.items[@intFromEnum(entity)] |= (@as(Signature, 1) << @intCast(getCompIndex(T)));
            self.getLayoutComp(T).items[@intFromEnum(entity)] = val;
        }
    };
}

pub fn MergeComponentSlices(groups: []const []const type) []const type {
    const len: usize = len: {
        var len: usize = 0;
        for (groups) |comps| len += comps.len;
        break :len len;
    };
    const out: [len]type = out: {
        var out: [len]type = undefined;
        var pos: usize = 0;
        for (groups) |comps| {
            @memcpy(out[pos .. pos + comps.len], comps);
            pos += comps.len;
        }
        break :out out;
    };
    return &out;
}
