const std = @import("std");

const PrintPathType = enum {
    regular,
    pointer,
};
const PrintPath = union(PrintPathType) {
    regular: []u8,
    pointer: ?[:0]const u8,
};
const PrinterInfo = struct {
    stdout: std.fs.File.Writer,
    home: [:0]const u8,
    color: [:0]const u8,
    no_color: [:0]const u8,
    not_host_env: ?[:0]const u8,
    path: PrintPath,
};

fn update_tmp_bash_env_content(os_cloud: ?[:0]const u8, kubeconfig: ?[:0]const u8, stdout: std.fs.File.Writer) !void {

    // TODO handle unset variables

    var kubecfg_file = try std.fs.createFileAbsolute("/tmp/._kubeconfig", .{ .truncate = true });
    // var kubecfg_file = try std.fs.openFileAbsolute("/tmp/._kubeconfig", .{
    //     .mode = .write_only,
    // });
    try kubecfg_file.writer().writeAll(kubeconfig.?);
    defer kubecfg_file.close();

    var openstack_file = try std.fs.createFileAbsolute("/tmp/._openstack_cloud", .{ .truncate = true });
    try openstack_file.writer().writeAll(os_cloud.?);
    defer openstack_file.close();

    // TODO trigger tmux refresh
    // https://github.com/oven-sh/bun/blob/93714292bfea5140c62b6750c71c91ed20d819c5/src/install/repository.zig#L114
    // https://github.com/evopen/ziglings/blob/614e7561737c340dcf8d7022b8e5bf8bcf22d84a/tools/check-exercises.zig#L33
    //
    const spin_off = @cImport({
        @cInclude("spin_off.c");
    });

    spin_off.tmux_refresh_client();

    // TODO remove
    _ = stdout;
    // var errno = std.c._errno().*;
    // try stdout.print("status:{d}:errno:{d}\n", .{
    //     status,
    //     errno,
    // });
    // _ = stdio.printf("%s\n", string.strerror(errno));
}

fn print_shortened_path(info: PrinterInfo) !void {
    // TODO optionals ... in_container
    // var args?
    //
    // prefix += "NOT_HOST_ENV: "
    //

    const stdout = info.stdout;
    const color = info.color;
    const no_color = info.no_color;

    var path: []u8 = "";
    switch (info.path) {
        .regular => path = info.path.regular,
        // https://ziglang.org/documentation/master/#toc-constCast
        .pointer => path = @constCast(info.path.pointer.?),
    }

    var path_split = std.mem.split(u8, path, "/");
    var prefix: []u8 = "";
    // why? https://ziglang.org/documentation/master/#:~:text=//%20Zig%20has%20no,%2C%20.%7B%20hello%2C%20world%20%7D)%3B
    var home_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const home_slice = home_buf[0..];
    // TODO fix null pointer deref if path = "/"
    // thread 30948312 panic: attempt to use null value
    // /Users/florian.sorko/Documents/zig/tools/bash-helper/main.zig:43:170: 0x1048acb3b in print_shortened_path (main)
    //     const home_concat = try std.fmt.bufPrint(home_slice, "{s}/{s}/{s}", .{ @constCast(path_split.next().?), @constCast(path_split.next().?), @constCast(path_split.next().?) });

    const home_concat = try std.fmt.bufPrint(home_slice, "{s}/{s}/{s}", .{ @constCast(path_split.next().?), @constCast(path_split.next().?), @constCast(path_split.next().?) });
    // try stdout.print("home_concat: {s}\n", .{home_concat});
    // _ = try std.fmt.bufPrint(home_slice, "{s}/{s}/{s}", .{ @constCast(path_split.next().?), @constCast(path_split.next().?), @constCast(path_split.next().?) });

    if (std.mem.eql(u8, info.home, home_concat)) {
        prefix = @constCast("~/");
    } else {
        prefix = home_concat;
    }

    //
    try stdout.print("{s}", .{color});
    try stdout.print("{?s}", .{prefix});
    var pre_previous: []u8 = "";
    var previous: []u8 = "";
    while (path_split.next()) |item| {
        if (pre_previous.len > 0) {
            try stdout.print("{c}/", .{pre_previous[0]});
        }
        pre_previous = previous;
        previous = @constCast(item);
    }
    try stdout.print("{s}/{s}", .{ pre_previous, previous });
    try stdout.print("{s}", .{no_color});
    // try stdout.print("home_buf: {?s}\n", .{home_buf});
    // try stdout.print("{s}{s}{s}", .{ color, path, no_color });
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.os.getcwd(&buf);
    // try stdout.print("cwd: {s}\n", .{cwd});

    const home = std.os.getenv("HOME");
    const os_cloud = std.os.getenv("OS_CLOUD");
    const kubeconfig = std.os.getenv("KUBECONFIG");
    const green = std.os.getenv("GREEN");
    const blue = std.os.getenv("BLUE");
    const no_color = std.os.getenv("NC");
    const virtualenv = std.os.getenv("VIRTUAL_ENV");
    const not_host_env = std.os.getenv("NOT_HOST_ENV");

    var print_path = PrintPath{
        .regular = cwd,
    };
    var info = PrinterInfo{
        .stdout = stdout,
        .home = home.?,
        .color = green.?,
        .no_color = no_color.?,
        .not_host_env = not_host_env,
        .path = print_path,
    };
    try print_shortened_path(info);

    if (virtualenv != null and virtualenv.?.len > 0) {
        print_path = PrintPath{
            .pointer = virtualenv,
        };
        info.path = print_path;
        info.color = blue.?;
        try stdout.print("{s}", .{" ("});
        try print_shortened_path(info);
        try stdout.print("{s}", .{")"});
    }

    try stdout.print("{s}", .{"\n$ "});

    try update_tmp_bash_env_content(os_cloud, kubeconfig, stdout);
}
