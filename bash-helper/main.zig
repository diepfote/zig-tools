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

fn update_tmp_bash_env_content(os_cloud: ?[:0]u8, kubeconfig: ?[:0]u8) !void {
    var local_kubeconfig: [:0]u8 = @constCast("");
    var local_os_cloud: [:0]u8 = @constCast("");
    if (kubeconfig != null) {
        local_kubeconfig = kubeconfig.?;
    }
    if (os_cloud != null) {
        local_os_cloud = os_cloud.?;
    }

    var kubecfg_file = try std.fs.createFileAbsolute("/tmp/._kubeconfig", .{ .truncate = true });
    // var kubecfg_file = try std.fs.openFileAbsolute("/tmp/._kubeconfig", .{
    //     .mode = .write_only,
    // });
    try kubecfg_file.writer().writeAll(local_kubeconfig);
    defer kubecfg_file.close();

    var openstack_file = try std.fs.createFileAbsolute("/tmp/._openstack_cloud", .{ .truncate = true });
    try openstack_file.writer().writeAll(local_os_cloud);
    defer openstack_file.close();

    // trigger tmux refresh
    //
    // https://github.com/oven-sh/bun/blob/93714292bfea5140c62b6750c71c91ed20d819c5/src/install/repository.zig#L114
    // https://github.com/evopen/ziglings/blob/614e7561737c340dcf8d7022b8e5bf8bcf22d84a/tools/check-exercises.zig#L33
    //
    const spin_off = @cImport({
        @cInclude("spin_off.c");
    });
    spin_off.tmux_refresh_client();
}

fn print_shortened_path(info: PrinterInfo) !void {
    const stdout = info.stdout;
    const color = info.color;
    const no_color = info.no_color;

    var path: []u8 = "";
    switch (info.path) {
        .regular => path = info.path.regular,
        // https://ziglang.org/documentation/master/#toc-constCast
        .pointer => path = @constCast(info.path.pointer.?),
    }

    // string.contains ... std.mem.count(u8, data, test_string) -> https://nofmal.github.io/zig-with-example/string-handling/
    var contains_home = if (std.mem.count(u8, path, info.home) > 0) true else false;
    var prefix = if (contains_home) "~/" else "/";

    var not_host_env_indicator: []u8 = @constCast("");
    if (info.not_host_env != null) {
        if (!std.mem.eql(u8, info.not_host_env.?, "")) {
            not_host_env_indicator = @constCast("NOT_HOST_ENV: ");
        }
    }

    try stdout.print("{?s}", .{not_host_env_indicator});
    try stdout.print("{s}", .{color});
    try stdout.print("{?s}", .{prefix});
    var pre_previous: []u8 = "";
    var previous: []u8 = "";

    path = if (contains_home) path[info.home.len..] else path;
    var path_split = std.mem.split(u8, path, "/");
    var count: u16 = 0;
    while (path_split.next()) |item| {
        count += 1;
        if (pre_previous.len > 0) {
            try stdout.print("{c}/", .{pre_previous[0]});
        }
        pre_previous = previous;
        previous = @constCast(item);
    }

    if (count < 2) {
        try stdout.print("{s}", .{no_color});
        return;
    } else if (count < 3) {
        try stdout.print("{s}", .{previous});
        try stdout.print("{s}", .{no_color});
        return;
    }

    // print last values for pre_previous and previous
    try stdout.print("{s}/{s}", .{ pre_previous, previous });
    try stdout.print("{s}", .{no_color});
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.os.getcwd(&buf);
    // try stdout.print("cwd: {s}\n", .{cwd});

    const home = std.os.getenv("HOME");
    var os_cloud = @constCast(std.os.getenv("OS_CLOUD"));
    var kubeconfig = @constCast(std.os.getenv("KUBECONFIG"));
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

    try update_tmp_bash_env_content(os_cloud, kubeconfig);
}
