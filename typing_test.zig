const std = @import("std");

const InlineTerm = @import("inline_term.zig");

pub fn main() !void {
    var term = try InlineTerm.init();
    defer term.deinit();
    errdefer term.deinit();

    var t0: u64 = @intCast(std.time.timestamp());
    var t: u64 = 0;
    var key: ?u8 = 0;
    while (true) {
        key = try term.readInput();
        if (key) |k| if (k == InlineTerm.key_esc) break;
        const t1 = @as(u64, @intCast(std.time.timestamp()));

        term.clear();
        try term.print("time: ", .{});
        term.color = .green;
        try term.print("{d:>3} ", .{t});
        term.color = .reset;
        try term.print("key: ", .{});
        term.color = .grey;
        try term.print("{d}", .{if (key) |k| k else 0});

        try term.update();
        if (t1 - t0 == 1) {
            t += 1;
            t0 = t1;
        }
        std.time.sleep(std.time.ns_per_s / 60);
    }
}
