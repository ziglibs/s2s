# struct to stream | stream to struct

A Zig binary serialization format and library.

## Features

- Convert (nearly) any Zig runtime datatype to binary data and back.
- No support for graph like structures. Everything is considered to be tree data.

**Unsupported types**:

- All `comptime` only types
- Unbound pointers (c pointers, pointer to many)
- Untagged or `external` unions
- Opaque types
- Function pointers
- Frames

## API

The library itself provides only some APIs, as most of the serialization process is not configurable.

```zig
/// Serializes the given `value: T` into the `stream`.
/// - `stream` is a instance of `std.io.Writer`
/// - `T` is the type to serialize
/// - `value` is the instance to serialize.
fn serialize(stream: anytype, comptime T: type, value: T) StreamError!void;

/// Deserializes a value of type `T` from the `stream`.
/// - `stream` is a instance of `std.io.Reader`
/// - `T` is the type to deserialize
fn deserialize(stream: anytype, comptime T: type) (StreamError || error{UnexpectedData,EndOfStream})!T;

/// Deserializes a value of type `T` from the `stream`.
/// - `stream` is a instance of `std.io.Reader`
/// - `T` is the type to deserialize
/// - `allocator` is an allocator require to allocate slices and pointers.
/// Result must be freed by using `free()`.
fn deserializeAlloc(stream: anytype, comptime T: type, allocator: std.mem.Allocator) (StreamError || error{ UnexpectedData, OutOfMemory,EndOfStream })!T;

/// Releases all memory allocated by `deserializeAlloc`.
/// - `allocator` is the allocator passed to `deserializeAlloc`.
/// - `T` is the type that was passed to `deserializeAlloc`.
/// - `value` is the value that was returned by `deserializeAlloc`.
fn free(allocator: std.mem.Allocator, comptime T: type, value: T) void;
```

## Project Status

**THIS PROJECT IS UNFINISHED, DO NOT USE YET!**

- [x] Implement frame data
  - [x] Compute a hash/id out of the structure definitions (this is used as a safety measure to prevent accidental deserialization of invalid data)
- [x] Implement serialization/deserialization
  - [x] Struct
  - [x] Tagged Union
  - [x] Integers
  - [x] Floats
  - [x] Arrays
  - [x] Slices (requires allocator)
  - [x] Booleans
  - [x] Optionals
  - [x] Vectors
  - [x] Enums
  - [x] ErrorSet (must be embedded in another type due to Zig properties and semantics)
  - [x] ErrorUnion (must be embedded in another type due to Zig properties and semantics)
- [ ] Tests
  - [x] Test pointer deserialization (requires extra code)
  - [x] Error deserialization
