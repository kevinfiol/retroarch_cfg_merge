const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    // defer _ = gpa.deinit();

    // parse arguments
    var output_file: ?[]const u8 = null;
    var input_files = std.ArrayList([]const u8).init(allocator);
    defer input_files.deinit();

    for (args[1..]) |arg| {
        // start at idx 1 because 0 is the executable
        if (std.mem.startsWith(u8, arg, "--output=")) {
            output_file = arg[9..]; // set output file to text after `=`
        } else {
            try input_files.append(arg);
        }
    }

    if (input_files.items.len < 1) {
        try printHelp();
        std.process.exit(1);
    }

    // create map of RA options
    var cfg = std.StringHashMap([]const u8).init(allocator);
    defer {
        var it = cfg.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        cfg.deinit();
    }

    for (input_files.items) |file_path| {
        try processCfg(allocator, &cfg, file_path);
    }

    if (output_file) |path| {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        const writer = file.writer();
        try writeConfig(writer, &cfg);
    } else {
        const stdout = std.io.getStdOut().writer();
        try writeConfig(stdout, &cfg);
    }
}

fn writeConfig(writer: anytype, cfg: *std.StringHashMap([]const u8)) !void {
    var it = cfg.iterator();
    while (it.next()) |kv| {
        try writer.print("{s} =", .{kv.key_ptr.*});
        try writer.print("{s}\n", .{kv.value_ptr.*});
    }
}

fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Usage: cfg_merge <one.cfg> [two.cfg ... [n].cfg] [--output=output_file]\n", .{});
    try stdout.print("  Merges multiple RetroArch config files, with later files taking precedence.\n", .{});
    try stdout.print("  If --output is not specified, the result is printed to stdout.\n", .{});
}

fn processCfg(allocator: std.mem.Allocator, cfg: *std.StringHashMap([]const u8), file_path: []const u8) !void {
    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const in_stream = buf_reader.reader();

    var buf: [1024]u8 = undefined;
    while (try nextLine(in_stream, &buf)) |line| {
        if (line.len == 0 or (line[0] == '#')) {
            continue;
        }

        if (std.mem.indexOf(u8, line, "=")) |equals_pos| {
            // get and trim key
            const key = std.mem.trim(u8, line[0..equals_pos], " \t"); // trim spaces and tabs
            if (key.len == 0) continue;

            // get value
            const value = line[equals_pos + 1 ..];

            // create owned copies?
            const key_owned = try allocator.dupe(u8, key);
            const value_owned = try allocator.dupe(u8, value);

            // check if key already exists
            if (cfg.getEntry(key_owned)) |entry| {
                // free old values
                allocator.free(entry.key_ptr.*);
                allocator.free(entry.value_ptr.*);

                // update with new values
                entry.key_ptr.* = key_owned;
                entry.value_ptr.* = value_owned;
            } else {
                // insert new key-value pair
                try cfg.put(key_owned, value_owned);
            }
        }
    }
}

fn nextLine(reader: anytype, buffer: []u8) !?[]const u8 {
    const line = (try reader.readUntilDelimiterOrEof(
        buffer,
        '\n',
    )) orelse return null;

    // trim annoying windows-only carriage return character
    const trimmed_line = if (builtin.os.tag == .windows)
        std.mem.trimRight(u8, line, "\r")
    else
        line;

    // trim leading and trailing whitespace
    return std.mem.trim(u8, trimmed_line, &std.ascii.whitespace);
}
