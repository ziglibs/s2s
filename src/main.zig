const std = @import("std");
const testing = std.testing;

/// Serializes the given `value: T` into the `stream`.
/// - `stream` is a instance of `std.io.Writer`
/// - `T` is the type to serialize
/// - `value` is the instance to serialize.
fn serialize(stream: anytype, comptime T: type, value: T) @TypeOf(stream).Error!void {
    const type_hash = computeTypeHash(T);

    try stream.writeAll(&type_hash);

    _ = value;
}

/// Deserializes a value of type `T` from the `stream`.
/// - `stream` is a instance of `std.io.Reader`
/// - `T` is the type to deserialize
fn deserialize(stream: anytype, comptime T: type) (@TypeOf(stream).Error || error{UnexpectedData})!T {
    if (comptime requiresAllocationForDeserialize(T))
        @compileError(@typeName(T) ++ " requires allocation to be deserialized. Use deserializeAlloc instead of deserialize!");
    return deserializeInternal(stream, T, null) catch |err| switch (err) {
        error.OutOfMemory => unreachable,
        else => |e| return e,
    };
}

/// Deserializes a value of type `T` from the `stream`.
/// - `stream` is a instance of `std.io.Reader`
/// - `T` is the type to deserialize
/// - `allocator` is an allocator require to allocate slices and pointers.
/// Result must be freed by using `free()`.
fn deserializeAlloc(stream: anytype, comptime T: type, allocator: std.mem.Allocator) (@TypeOf(stream).Error || error{ UnexpectedData, OutOfMemory })!T {
    return try deserializeInternal(stream, T, allocator);
}

/// Releases all memory allocated by `deserializeAlloc`.
/// - `allocator` is the allocator passed to `deserializeAlloc`.
/// - `T` is the type that was passed to `deserializeAlloc`.
/// - `value` is the value that was returned by `deserializeAlloc`.
fn free(allocator: std.mem.Allocator, comptime T: type, value: T) void {
    _ = allocator;
    _ = T;
    _ = value;
}

fn deserializeInternal(stream: anytype, comptime T: type, allocator: ?std.mem.Allocator) (@TypeOf(stream).Error || error{ UnexpectedData, OutOfMemory })!T {
    const type_hash = computeTypeHash(T);

    var ref_hash: [type_hash.len]u8 = undefined;
    try stream.readAll(&ref_hash);
    if (!std.mem.eql(u8, &type_hash, &ref_hash))
        return error.UnexpectedData;

    _ = allocator;
}

/// Returns `true` if `T` requires allocation to be deserialized.
fn requiresAllocationForDeserialize(comptime T: type) bool {
    switch (@typeInfo(T)) {
        .Pointer => true,
        .Struct, .Union => {
            inline for (comptime std.meta.fields(T)) |fld| {
                if (requiresAllocationForDeserialize(fld.field_type))
                    return true;
            }
            return false;
        },
        .ErrorUnion => |eu| return requiresAllocationForDeserialize(eu.payload),
        else => return false,
    }
}

const TypeHashFn = std.hash.Fnv1a_64;

fn intToLittleEndianBytes(val: anytype) [@sizeOf(@TypeOf(val))]u8 {
    var res: [@sizeOf(@TypeOf(val))]u8 = undefined;
    std.mem.writeIntLittle(@TypeOf(val), &res, val);
    return res;
}

/// Computes a unique type hash from `T` to identify deserializing invalid data.
/// Incorporates field order and field type, but not field names, so only checks for structural equivalence.
/// Compile errors on unsupported or comptime types.
fn computeTypeHash(comptime T: type) [8]u8 {
    var hasher = TypeHashFn.init();

    computeTypeHashInternal(&hasher, T);

    return intToLittleEndianBytes(hasher.final());
}

fn getSortedErrorNames(comptime T: type) []const []const u8 {
    comptime {
        const error_set = @typeInfo(T).ErrorSet orelse @compileError("Cannot serialize anyerror");

        var sorted_names: [error_set.len][]const u8 = undefined;
        for (error_set) |err, i| {
            sorted_names[i] = err.name;
        }

        std.sort.sort([]const u8, &sorted_names, {}, struct {
            fn order(ctx: void, lhs: []const u8, rhs: []const u8) bool {
                _ = ctx;
                return (std.mem.order(u8, lhs, rhs) == .lt);
            }
        }.order);
        return &sorted_names;
    }
}

fn computeTypeHashInternal(hasher: *TypeHashFn, comptime T: type) void {
    switch (@typeInfo(T)) {
        // Primitive types:
        .Void,
        .Bool,
        .Float,
        => hasher.update(@typeName(T)),

        .Int => {
            if (T == usize) {
                // special case: usize can differ between platforms, this
                // format uses u64 internally.
                hasher.update(@typeName(u64));
            } else {
                hasher.update(@typeName(T));
            }
        },
        .Pointer => |ptr| {
            if (ptr.sentinel != null) @compileError("Sentinels are not supported yet!");
            switch (ptr.size) {
                .One => {
                    hasher.update("pointer");
                    computeTypeHashInternal(hasher, ptr.child);
                },
                .Slice => {
                    hasher.update("slice");
                    computeTypeHashInternal(hasher, ptr.child);
                },
                .C => @compileError("C-pointers are not supported"),
                .Many => @compileError("Many-pointers are not supported"),
            }
        },
        .Array => |arr| {
            hasher.update(&intToLittleEndianBytes(@as(u64, arr.len)));
            computeTypeHashInternal(hasher, arr.child);
            if (arr.sentinel != null) @compileError("Sentinels are not supported yet!");
        },
        .Struct => |str| {
            // we can safely ignore the struct layout here as we will serialize the data by field order,
            // instead of memory representation

            // add some generic marker to the hash so emtpy structs get
            // added as information
            hasher.update("struct");

            for (str.fields) |fld| {
                if (fld.is_comptime) @compileError("comptime fields are not supported.");
                computeTypeHashInternal(hasher, fld.field_type);
            }
        },
        .Optional => |opt| {
            hasher.update("optional");
            computeTypeHashInternal(hasher, opt.child);
        },
        .ErrorUnion => |eu| {
            hasher.update("error union");
            computeTypeHashInternal(hasher, eu.error_set);
            computeTypeHashInternal(hasher, eu.payload);
        },
        .ErrorSet => {
            const names = getSortedErrorNames(T);

            // Error unions are serialized by "index of sorted name", so we
            // hash all names in the right order
            hasher.update("error set");
            for (names) |name| {
                hasher.update(name);
            }
        },
        .Enum => |list| {
            hasher.update("enum");
            computeTypeHashInternal(hasher, list.tag_type);
        },
        .Union => |un| {
            const tag = un.tag_type orelse @compileError("Untagged unions are not supported!");
            hasher.update("union");
            computeTypeHashInternal(hasher, tag);
            for (un.fields) |fld| {
                computeTypeHashInternal(hasher, fld.field_type);
            }
        },
        .Vector => |vec| {
            hasher.update("vector");
            hasher.update(&intToLittleEndianBytes(@as(u64, vec.len)));
            computeTypeHashInternal(hasher, vec.child);
        },

        // Unsupported types:
        .NoReturn,
        .Type,
        .ComptimeFloat,
        .ComptimeInt,
        .Undefined,
        .Null,
        .Fn,
        .BoundFn,
        .Opaque,
        .Frame,
        .AnyFrame,
        .EnumLiteral,
        => @compileError("Unsupported type " ++ @typeName(T)),
    }
}

fn testSameHash(comptime T1: type, comptime T2: type) void {
    const hash_1 = comptime computeTypeHash(T1);
    const hash_2 = comptime computeTypeHash(T2);
    if (comptime !std.mem.eql(u8, &hash_1, &hash_2))
        @compileError("The computed hash for " ++ @typeName(T1) ++ " and " ++ @typeName(T2) ++ " does not match.");
}

test "type hasher basics" {
    testSameHash(void, void);
    testSameHash(bool, bool);
    testSameHash(u1, u1);
    testSameHash(u32, u32);
    testSameHash(f32, f32);
    testSameHash(f64, f64);
    testSameHash(std.meta.Vector(4, u32), std.meta.Vector(4, u32));
    testSameHash(usize, u64);
    testSameHash([]const u8, []const u8);
    testSameHash([]const u8, []u8);
    testSameHash([]const volatile u8, []u8);
    testSameHash([]const volatile u8, []const u8);
    testSameHash(?*volatile struct { a: f32, b: u16 }, ?*const struct { hello: f32, lol: u16 });
    testSameHash(enum { a, b, c }, enum { a, b, c });
    testSameHash([5]std.meta.Vector(4, u32), [5]std.meta.Vector(4, u32));

    testSameHash(union(enum) { a: u32, b: f32 }, union(enum) { hendlo: u32, blafasel: f32 });

    testSameHash(error{ Foo, Bar }, error{ Foo, Bar });
    testSameHash(error{ Foo, Bar }, error{ Bar, Foo });
    testSameHash(error{ Foo, Bar }!void, error{ Bar, Foo }!void);
}
