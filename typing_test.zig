const std = @import("std");

const InlineTerm = @import("inline_term.zig");

pub fn main() !void {
    var term = try InlineTerm.init();
    defer term.deinit();
    errdefer term.deinit();

    const text =
        "Stenaelurillus albus is a species of jumping spider" ++
        " in the genus Stenaelurillus that lives in India. I" ++
        "t was first described in 2015 by Pothalil A. Sebast" ++
        "ian, Pradeep M. Sankaran, Jobi J. Malamel and Mathe" ++
        "w M. Joseph.";

    var t0: u64 = @intCast(std.time.timestamp());
    var t: u64 = 0;
    var key: ?u8 = 0;
    var text_pos: usize = 0;
    while (true) {
        key = try term.readInput();
        if (key) |k| if (k == InlineTerm.key_esc) break;

        term.clear();

        term.color = .green;
        try term.print("  {d:>3}  ", .{t});

        // window to display
        const text_space = InlineTerm.bufsize - term.cursor;
        const start = @min(if (text_pos < 4) 0 else text_pos - 4, text.len - text_space);
        const end = start + text_space;

        const cursor = term.cursor;
        term.color = .grey;
        try term.print("{s}", .{text[start..end]});

        // cursor pos
        const pad = 4;
        term.cursor = cursor + if (text_pos <= pad)
            text_pos
        else if (text_pos > text.len - text_space + pad)
            text_pos - start
        else
            pad;

        // input
        if (key) |k| {
            if (k == InlineTerm.key_backspace) {
                text_pos -= if (text_pos == 0) 0 else 1;
                // TODO: set color
            } else {
                // TODO: set color
                //
                text_pos += if (text_pos >= text.len) 0 else 1;
            }
        }

        // loop stuff
        try term.update();
        const t1 = @as(u64, @intCast(std.time.timestamp()));
        if (t1 - t0 == 1) {
            t += 1;
            t0 = t1;
        }
        std.time.sleep(std.time.ns_per_s / 60);
    }
}
