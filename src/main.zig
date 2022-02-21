const std = @import("std");
const testing = std.testing;

/// Serializes the given `value: T` into the `stream`.
/// - `stream` is a instance of `std.io.Writer`
/// - `T` is the type to serialize
/// - `value` is the instance to serialize.
fn serialize(stream: anytype, comptime T: type, value: T) @TypeOf(stream).Error!void {
    const type_hash = computeTypeHash(T);
    //
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
    //
}

fn deserializeInternal(stream: anytype, comptime T: type, allocator: ?std.mem.Allocator) (@TypeOf(stream).Error || error{ UnexpectedData, OutOfMemory })!T {
    const type_hash = computeTypeHash(T);
    //
}

/// Returns `true` if `T` requires allocation to be deserialized.
fn requiresAllocationForDeserialize(comptime T: type) bool {
    @panic("not implemented!");
}

/// Computes a unique type hash from `T` to identify deserializing invalid data.
/// Incorporates field order and field type, but not field names, so only checks for structural equivalence.
/// Compile errors on unsupported or comptime types.
fn computeTypeHash(comptime T: type) [8]u8 {
    @panic("not implemented!");
}
