const std = @import("std");

const InlineTerm = @import("inline_term.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Usage: {s} [FILE]\n", .{std.fs.path.basename(args[0])});
        try stderr.print("will freak out if terminal width is less than {d}\n", .{InlineTerm.bufsize});
        return;
    }
    if (args.len > 2) {
        std.log.info("ignoring extra args", .{});
    }
    const file = try std.fs.cwd().openFile(args[1], .{.mode = .read_only});
    defer file.close();
    const reader = file.reader();

    var text_al = std.ArrayList(u8).init(allocator);
    defer text_al.deinit();
    try streamAllIgnoreControlAndCollapseBlank(reader, text_al.writer());
    const text = text_al.items;

    var modes = try allocator.alloc(InlineTerm.Mode, text.len);
    defer allocator.free(modes);
    @memset(modes, .grey);

    var term = try InlineTerm.init();
    errdefer term.deinit();

    var t0: u64 = @intCast(std.time.timestamp());
    var t: u64 = 0;
    var key: ?u8 = 0;
    var text_pos: usize = 0;
    while (true) {
        // time
        const t1 = @as(u64, @intCast(std.time.timestamp()));
        if (t1 - t0 == 1) {
            t += 1;
            t0 = t1;
        }
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

        term.mode = .blue;        try term.print(" {d:>3}", .{t});
        term.mode = .yellow;      try term.print(" {d:>3}", .{text_pos});
        term.mode = .yellow_dark; try term.print("/", .{});
        term.mode = .yellow;      try term.print("{d}  ", .{text.len});

        // window to display
        const text_space = InlineTerm.bufsize - term.cursor;
        const offset = 5;
        const start = @min(
            if (text_pos > offset) text_pos - offset else 0,        // distance from text start
            if (text.len > text_space) text.len - text_space else 0 // distance from text end
        );
        const end = start + @min(text_space, text.len);

        const cursor = term.cursor;
        try term.print("{s}", .{text[start..end]});
        // overwrite auto set mode
        @memcpy(term.modes[cursor..cursor + (end - start)], modes[start..end]);

        // cursor pos
        term.cursor = cursor + if (text_pos <= offset)
            text_pos
        else if (text_pos + text_space > text.len + offset)
            text_pos - start
        else
            offset;

        // loop stuff
        try term.update();
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
    try stdout.print("accuracy: {d:>2.2}%\n", .{(right / @as(f32, @floatFromInt(text.len))) * 100});
}

fn streamAllIgnoreControlAndCollapseBlank(reader: anytype, writer: anytype) !void {
    // skip initial whitespace and control chars
    while (true) {
        const byte = reader.readByte() catch |e| {
            if (e == error.EndOfStream) return
            else return e;
        };
        if (!std.ascii.isControl(byte) and !std.ascii.isWhitespace(byte)) {
            try writer.writeByte(byte);
            break;
        }
    }

    var in_blank: bool = false;
    while (true) {
        const byte = reader.readByte() catch |e| {
            if (e == error.EndOfStream) return
            else return e;
        };
        if (!std.ascii.isControl(byte) and !std.ascii.isWhitespace(byte)) {
            if (in_blank) try writer.writeByte(' ');
            try writer.writeByte(byte);
            in_blank = false;
        } else in_blank = true;
    }
}

test "streamAllIgnoreControlAndCollapseBlank" {
    const input = "     hey   there\n  hi  h";
    const output = "hey there hi h";

    var output_al = std.ArrayList(u8).init(std.testing.allocator);
    defer output_al.deinit();
    var fbs = std.io.fixedBufferStream(input);
    const reader = fbs.reader();

    try streamAllIgnoreControlAndCollapseBlank(reader, output_al.writer());

    try std.testing.expectEqualStrings(output, output_al.items);
}
