const std = @import("std");
const builtin = @import("builtin");
const is_debug = builtin.mode == .Debug;

const _print = std.debug.print;
var stdout_mutex = std.Thread.Mutex{};

// based on https://zig.news/kristoff/where-is-print-in-zig-57e9
pub fn debug(comptime fmt: []const u8, args: anytype) void {
    if (is_debug) {
        _print("{s}", .{"[DEBUG]: "});
        _print(fmt, args);
        _print("{s}", .{"\n"});
    }
}

pub fn log_info(comptime fmt: []const u8, args: anytype) void {
    _print("{s}", .{"[INFO]: "});
    _print(fmt, args);
}

pub fn log_err(comptime fmt: []const u8, args: anytype) void {
    _print("{s}", .{"[ERROR]: "});
    _print(fmt, args);
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    stdout_mutex.lock();
    defer stdout_mutex.unlock();

    const stdout = std.io.getStdOut().writer();
    nosuspend stdout.print(fmt, args) catch return;
}
