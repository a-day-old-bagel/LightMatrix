const std = @import("std");
const zig_serial = @import("serial");
const zstbi = @import("zstbi");

const image_width = 32;
const image_height = 16;
const image_byte_size = image_width * image_height * 3;

pub fn main() !u8 {

    const image_sequence_dir = "shark_frames";

    std.debug.print("\nDevices:\n", .{});
    var ports = try zig_serial.list();
    while (try ports.next()) |port| {
        std.debug.print("\t{s}: {s}\n", .{ port.file_name, port.driver orelse "No Driver Info" });
    }

    const port_name = if (@import("builtin").os.tag == .windows) "\\\\.\\COM8" else "/dev/ttyUSB6";
    std.debug.print("\nUsing {s}...\n\n", .{ port_name });

    var serial = std.fs.cwd().openFile(port_name, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Invalid config: the serial port '{s}' does not exist.\n", .{port_name});
            return 1;
        },
        error.AccessDenied => {
            std.debug.print(
                "Access Denied: Ensure port is not already in use, or possibly try running {s}",
                .{ if (@import("builtin").os.tag == .windows) "as Administrator.\n" else "with elevated privileges\n" }
            );
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

    var heap = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = heap.deinit(); // memory leak check inside deinit
    const alloc = heap.allocator();

    zstbi.init(alloc);
    defer zstbi.deinit();

    const cwd = std.fs.cwd();
    std.debug.print("Sending {s}...\n", .{ image_sequence_dir });
    const seq_dir = try cwd.openDir(image_sequence_dir, .{ .iterate = true });
    var seq_it = seq_dir.iterate();
    while (try seq_it.next()) |file_entry| {
        const file_name = try std.fmt.allocPrintZ(alloc, "{s}/{s}", .{ image_sequence_dir, file_entry.name });
        defer alloc.free(file_name);
        std.debug.print("\t{s}\n", .{ file_name });

        var image = try zstbi.Image.loadFromFile(file_name, 3);
        defer image.deinit();
        if (image.width != image_width or image.height != image_height) return error.IncorrectImageDimensions;

        var message = try std.ArrayList(u8).initCapacity(alloc, image_byte_size);
        const dimmer_divisor = 1;
        createImageMessage(&message, dimmer_divisor, &image);

        try serial.writer().writeAll(message.items);
    }

    return 0;
}

fn createImageMessage(arrayList: *std.ArrayList(u8), dimmer_divisor: u8, image: *const zstbi.Image) void {
    arrayList.clearRetainingCapacity();
    for (0..arrayList.capacity / 3) |i| {
        const col_index = i / 16;
        var row_index = i % 16;
        if (col_index % 2 == 1) row_index = 15 - row_index;
        const pixel_base_index = (row_index * 32 + col_index) * 3;
        arrayList.appendAssumeCapacity(image.data[pixel_base_index + 0] / dimmer_divisor);
        arrayList.appendAssumeCapacity(image.data[pixel_base_index + 1] / dimmer_divisor);
        arrayList.appendAssumeCapacity(image.data[pixel_base_index + 2] / dimmer_divisor);
    }
}

fn createTestPattern(arrayList: *std.ArrayList(u8), dimmer_divisor: u8) void {
    arrayList.clearRetainingCapacity();
    for (0..arrayList.capacity / 3) |i| {
        const col_index = @as(u8, @intCast(i / 16));
        var row_index = @as(u8, @intCast(i % 16));
        if (col_index % 2 == 1) row_index = 15 - row_index;
        arrayList.appendAssumeCapacity((255 - col_index * 8) / dimmer_divisor);
        arrayList.appendAssumeCapacity((row_index * 16) / dimmer_divisor);
        arrayList.appendAssumeCapacity((col_index * 8) / dimmer_divisor);
    }
}