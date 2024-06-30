const std = @import("std");
const zig_serial = @import("serial");
const zstbi = @import("zstbi");

const image_width = 32;
const image_height = 16;
const image_byte_size = image_width * image_height * 3;

pub fn main() !u8 {

    const image_sequence_dir = "shark_frames";
    const send_compressed = true;

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

        const dimmer_divisor = 1;
        if (send_compressed) {
            var message = try std.ArrayList(u8).initCapacity(alloc, image_width * image_height * 2);
            defer message.deinit();
            createImageMessageCompressed(&message, dimmer_divisor, &image);
            try serial.writer().writeAll(message.items);
        } else {
            var message = try std.ArrayList(u8).initCapacity(alloc, image_byte_size);
            defer message.deinit();
            createImageMessage(&message, dimmer_divisor, &image);
            try serial.writer().writeAll(message.items);
        }
    }

    return 0;
}

fn createImageMessage(pixel_list: *std.ArrayList(u8), dimmer_divisor: u8, image: *const zstbi.Image) void {
    pixel_list.clearRetainingCapacity();
    for (0..pixel_list.capacity / 3) |i| {
        const col_index = i / 16;
        var row_index = i % 16;
        if (col_index % 2 == 1) row_index = 15 - row_index;
        const pixel_base_index = (row_index * 32 + col_index) * 3;
        pixel_list.appendAssumeCapacity(image.data[pixel_base_index + 0] / dimmer_divisor);
        pixel_list.appendAssumeCapacity(image.data[pixel_base_index + 1] / dimmer_divisor);
        pixel_list.appendAssumeCapacity(image.data[pixel_base_index + 2] / dimmer_divisor);
    }
}

fn createImageMessageCompressed(pixel_list: *std.ArrayList(u8), dimmer_divisor: u8, image: *const zstbi.Image) void {
    pixel_list.clearRetainingCapacity();
    for (0..pixel_list.capacity / 2) |i| {
        const col_index = i / 16;
        var row_index = i % 16;
        if (col_index % 2 == 1) row_index = 15 - row_index;
        const pixel_base_index = (row_index * 32 + col_index) * 3;
        const r: u8 = image.data[pixel_base_index + 0] / dimmer_divisor;
        const g: u8 = image.data[pixel_base_index + 1] / dimmer_divisor;
        const b: u8 = image.data[pixel_base_index + 2] / dimmer_divisor;

        var little: u8 = b >> 3;
        little |= (g >> 2) << 5;

        var big: u8 = (g >> 5);
        big |= (r >> 3) << 3;

        pixel_list.appendAssumeCapacity(big);
        pixel_list.appendAssumeCapacity(little);
    }
}

fn createTestPattern(pixel_list: *std.ArrayList(u8), dimmer_divisor: u8) void {
    pixel_list.clearRetainingCapacity();
    for (0..pixel_list.capacity / 3) |i| {
        const col_index = @as(u8, @intCast(i / 16));
        var row_index = @as(u8, @intCast(i % 16));
        if (col_index % 2 == 1) row_index = 15 - row_index;
        pixel_list.appendAssumeCapacity((255 - col_index * 8) / dimmer_divisor);
        pixel_list.appendAssumeCapacity((row_index * 16) / dimmer_divisor);
        pixel_list.appendAssumeCapacity((col_index * 8) / dimmer_divisor);
    }
}