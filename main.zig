const std = @import("std");
const zig_serial = @import("serial");
const image_pixel_count = 512;
const image_byte_size = image_pixel_count * 3;

pub fn main() !u8 {
    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM7" else "/dev/ttyUSB6";

    var serial = std.fs.cwd().openFile(port_name, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{port_name});
            return 1;
        },
        else => return err,
    };
    defer serial.close();

    try zig_serial.configureSerialPort(serial, zig_serial.SerialConfig{
        .baud_rate = 115200,
        .word_size = .eight,
        .parity = .none,
        .stop_bits = .one,
        .handshake = .none,
    });

    var page_alloc: std.mem.Allocator = std.heap.page_allocator;
    const fixed_buffer = try page_alloc.alloc(u8, image_byte_size);
    var heap = std.heap.FixedBufferAllocator.init(fixed_buffer);
    const alloc: std.mem.Allocator = heap.allocator();

    var message = try std.ArrayList(u8).initCapacity(alloc, image_byte_size);
    for (0..image_pixel_count) |i| {
        const dimmer = 16;
        const columnIndex = @as(u8, @intCast(i / 16));
        try message.append((255 - columnIndex * 8) / dimmer);
        try message.append((0) / dimmer);
        try message.append((columnIndex * 8) / dimmer);
    }

    try serial.writer().writeAll(message.items);

    // while (true) {
    //     const b = try serial.reader().readByte();
    //     try serial.writer().writeByte(b);
    // }

    return 0;
}