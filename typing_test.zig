const std = @import("std");

const InlineTerm = @import("inline_term.zig");

pub fn main() !void {
    // TODO: take arguments

    var term = try InlineTerm.init();
    errdefer term.deinit();

    // TODO: fix crash when text.len < text_space
    const text =
        "Are you feeling nervous? Are you having fun? " ++ 
        "It's almost over, It's just begun, Don't overthink this, " ++ 
        "Look in my eye, Don't be scared, Don't be shy, " ++
        "Come on in, the water's fine";
    var modes: [text.len]InlineTerm.Mode = .{.grey}**text.len;

    var t0: u64 = @intCast(std.time.timestamp());
    var t: u64 = 0;
    var key: ?u8 = 0;
    var text_pos: usize = 0;
    while (true) {
        // input
        key = try term.readInput();
        if (key) |k| { switch (k) {
            InlineTerm.key_esc => break,
            InlineTerm.key_backspace => {
                text_pos -= if (text_pos == 0) 0 else 1;
                modes[text_pos] = .grey;
            },
            else => {
                modes[text_pos] = if (k == text[text_pos]) .reset else .red_underlined;
                text_pos += if (text_pos >= text.len) 0 else 1;
            }
        }}

        term.clear();

        term.mode = .blue;
        try term.print("  {d:>3}  ", .{t});

        // window to display
        const text_space = InlineTerm.bufsize - term.cursor;
        const offset = 5;
        const start = @min(if (text_pos < offset) 0 else text_pos - offset, text.len - text_space);
        const end = start + text_space;

        const cursor = term.cursor;
        try term.print("{s}", .{text[start..end]});
        // overwrite auto set mode
        @memcpy(term.modes[cursor..], modes[start..end]);

        // cursor pos
        term.cursor = cursor + if (text_pos <= offset)
            text_pos
        else if (text_pos > text.len - text_space + offset)
            text_pos - start
        else
            offset;

        // loop stuff
        try term.update();
        const t1 = @as(u64, @intCast(std.time.timestamp()));
        if (t1 - t0 == 1) {
            t += 1;
            t0 = t1;
        }
        std.time.sleep(std.time.ns_per_s / 60);
        if (text_pos >= text.len) break;
    }

    const stdout = std.io.getStdOut().writer();

    if (key) |k| if (k == InlineTerm.key_esc) {
        term.deinit();
        try stdout.print("exit\n", .{});
        return;
    };

    var right: f32 = 0;
    for (modes) |mode| {
        switch (mode) {
            .reset => right += 1,
            .red_underlined => {},
            else => unreachable
        }
    }

    term.deinit();
    // print stats
    try stdout.print("    time: {d} seconds\n", .{t});
    try stdout.print("   right: {d}/{d}\n", .{right, text.len});
    try stdout.print("accuracy: {d:>2.2}%\n", .{(right / text.len) * 100});
}
