const std = @import("std");

pub fn write_file(filename: []const u8, content: []const u8) !void {
    var f = try std.fs.createFileAbsolute(filename, .{ .truncate = true });
    defer f.close();
    try f.writer().writeAll(content);
}
