const Self = @This();
const std = @import("std");

pub const Mode = enum(u8) { blue, red_underlined, grey, reset };

pub const key_esc = 27;
pub const key_backspace = 127;

pub const bufsize = 32;

stdin_file: std.fs.File,
stdin: @TypeOf(std.io.getStdIn().reader()),
stdout: @TypeOf(std.io.getStdOut().writer()),
old_term: std.posix.termios,

cursor: usize,
line: [bufsize]u8,
modes: [bufsize]Mode,
mode: Mode,

const error_set = std.posix.TermiosGetError || std.posix.TermiosSetError || std.posix.FcntlError;
pub fn init() error_set!Self {
    var self: Self = undefined;
    self.stdin_file = std.io.getStdOut();
    self.stdin = self.stdin_file.reader();
    self.stdout = std.io.getStdOut().writer();

    self.cursor = 0;
    self.line   = .{' '}**bufsize;
    self.modes = .{.reset}**bufsize;
    self.mode = .reset;

    // cbreak(); noecho();
    self.old_term = try std.posix.tcgetattr(self.stdin_file.handle);
    var term = self.old_term;
    term.lflag.ICANON = false;
    term.lflag.ECHO = false;
    try std.posix.tcsetattr(self.stdin_file.handle, std.posix.TCSA.NOW, term);

    // nodelay();
    var flags: std.posix.O = @bitCast(@as(u32, @intCast(try std.posix.fcntl(self.stdin_file.handle, std.posix.F.GETFL, 0))));
    flags.NONBLOCK = true;
    _ = try std.posix.fcntl(self.stdin_file.handle, std.posix.F.SETFL, @intCast(@as(u32, @bitCast(flags))));

    return self;
}

pub fn deinit(self: *Self) void {
    std.posix.tcsetattr(self.stdin_file.handle, std.posix.TCSA.NOW, self.old_term) catch {};
    self.stdout.print("\n", .{}) catch {};
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    var fbs = std.io.fixedBufferStream(self.line[self.cursor..]);
    const writer = fbs.writer();
    writer.print(fmt, args) catch |e| {
        if (e == error.NoSpaceLeft) {
            self.cursor = self.line.len;
            return;
        } else return e;
    };

    const len = std.fmt.count(fmt, args);
    @memset(self.modes[self.cursor..self.cursor + len], self.mode);
    self.cursor += len;
}

pub fn clear(self: *Self) void {
    self.mode = .reset;
    self.cursor = 0;
    for (&self.line) |*ch| {
        ch.* = ' ';
    }
}

pub fn update(self: Self) !void {
    try self.stdout.print("\x1B[G", .{}); // go to beginning of line

    var mode = self.modes[0];
    var i_1: usize = 0;
    var i_2: usize = 0;
    while (i_2 < self.line.len) : (i_2 += 1) {
        if (self.modes[i_2] != mode) {
            try self.updateMode(mode);
            try self.stdout.print("{s}", .{self.line[i_1..i_2]});
            mode = self.modes[i_2];
            i_1 = i_2;
        }
    }

    try self.updateMode(self.modes[i_1]);
    try self.stdout.print("{s}\x1B[m", .{self.line[i_1..i_2]});
    try self.stdout.print("\x1B[{d}G", .{self.cursor + 1}); // go to cursor
}

fn updateMode(self: Self, mode:  Mode) !void {
    try self.stdout.print("\x1B[m", .{});
    try self.stdout.print("\x1B[{s}m", .{switch (mode) {
        .blue => "1;34",
        .grey  => "1;30",
        .red_underlined => "1;4;31",
        .reset => ""
    }});
}

pub fn readInput(self: Self) !?u8 {
    return self.stdin.readByte() catch |e| {
        if (e == error.WouldBlock) return null
        else return e;
    };
}
