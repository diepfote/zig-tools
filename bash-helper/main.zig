const std = @import("std");

const _print = @import("print.zig");
const print = _print.print;
const debug = _print.debug;
const log_info = _print.log_info;
const log_err = _print.log_err;

const file_io = @import("file_io.zig");
const write_file = file_io.write_file;

const PrintPathType = enum {
    regular,
    pointer,
};
const PrintPath = union(PrintPathType) {
    regular: []u8,
    pointer: ?[:0]const u8,
};
const PrinterInfo = struct {
    home: [:0]const u8,
    color: [:0]const u8,
    no_color: [:0]const u8,
    not_host_env: ?[:0]const u8,
    not_host_env_color: [:0]const u8,
    path: PrintPath,
    is_virtualenv_path: bool,
};

fn tmux_refresh_client() !void {
    // snatched from:
    // https://renatoathaydes.github.io/zig-common-tasks/samples/alloc.zig
    // https://renatoathaydes.github.io/zig-common-tasks/samples/exec_process.zig

    const argv = [_][]const u8{ "tmux", "refresh-client" };

    // init a ChildProcess... cleanup is done by calling wait().
    const alloc: std.mem.Allocator = std.heap.page_allocator;
    var proc = std.process.Child.init(&argv, alloc);

    // ignore the streams to avoid the zig build blocking...
    // REMOVE THESE IF YOU ACTUALLY WANT TO INHERIT THE STREAMS.
    proc.stdin_behavior = .Ignore;
    proc.stdout_behavior = .Ignore;
    proc.stderr_behavior = .Ignore;

    proc.spawn() catch return;

    debug("Spawned process PID: {d}", .{proc.id});
}

fn update_tmp_bash_env_content(os_cloud: ?[:0]u8, kubeconfig: ?[:0]u8) !void {
    var local_kubeconfig: [:0]u8 = @constCast("");
    var local_os_cloud: [:0]u8 = @constCast("");
    if (kubeconfig != null) {
        local_kubeconfig = kubeconfig.?;
    }
    if (os_cloud != null) {
        local_os_cloud = os_cloud.?;
    }

    // these will crash if the variable is unset/nil
    debug("local_kubeconfig: {s}", .{local_kubeconfig});
    debug("local_os_cloud: {s}", .{local_os_cloud});

    try write_file(@constCast("/tmp/._kubeconfig"), local_kubeconfig);
    try write_file(@constCast("/tmp/._openstack_cloud"), local_os_cloud);

    try tmux_refresh_client();
}

fn print_shortened_path(info: PrinterInfo) !void {
    const color = info.color;
    const host_color = info.not_host_env_color;
    const no_color = info.no_color;

    var path: []u8 = "";
    switch (info.path) {
        .regular => path = info.path.regular,
        // https://ziglang.org/documentation/master/#toc-constCast
        .pointer => path = @constCast(info.path.pointer.?),
    }

    // string.contains ... std.mem.count(u8, data, test_string) -> https://nofmal.github.io/zig-with-example/string-handling/
    const contains_home = if (std.mem.count(u8, path, info.home) > 0) true else false;
    const prefix = if (contains_home) "~/" else "/";

    if (info.not_host_env != null) {
        if (!std.mem.eql(u8, info.not_host_env.?, "")) {
            if (!info.is_virtualenv_path) {
                print("{?s}", .{host_color});
                print("{?s}", .{"NOT_HOST_ENV: "});
                print("{?s}", .{no_color});
            }
        }
    }
    print("{s}", .{color});
    print("{?s}", .{prefix});
    var pre_previous: []u8 = "";
    var previous: []u8 = "";

    path = if (contains_home) path[info.home.len..] else path;
    var path_split = std.mem.split(u8, path, "/");
    var count: u16 = 0;
    while (path_split.next()) |item| {
        count += 1;
        if (pre_previous.len > 0) {
            print("{c}/", .{pre_previous[0]});
        }
        pre_previous = previous;
        previous = @constCast(item);
    }

    if (count < 2) {
        print("{s}", .{no_color});
        return;
    } else if (count < 3) {
        print("{s}", .{previous});
        print("{s}", .{no_color});
        return;
    }

    // print last values for pre_previous and previous
    print("{s}/{s}", .{ pre_previous, previous });
    print("{s}", .{no_color});
}

pub fn main() !void {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const cwd = try std.posix.getcwd(&buf);
    // print("cwd: {s}\n", .{cwd});

    const home = std.posix.getenv("HOME");
    const os_cloud = @constCast(std.posix.getenv("OS_CLOUD"));
    const kubeconfig = @constCast(std.posix.getenv("KUBECONFIG"));
    const green = std.posix.getenv("GREEN");
    const blue = std.posix.getenv("BLUE");
    const red = std.posix.getenv("RED");
    const no_color = std.posix.getenv("NC");
    const virtualenv = std.posix.getenv("VIRTUAL_ENV");
    const not_host_env = std.posix.getenv("NOT_HOST_ENV");

    var print_path = PrintPath{
        .regular = cwd,
    };
    var info = PrinterInfo{
        .home = home.?,
        .color = green.?,
        .no_color = no_color.?,
        .not_host_env = not_host_env,
        .not_host_env_color = red.?,
        .path = print_path,
        .is_virtualenv_path = false,
    };
    try print_shortened_path(info);

    if (virtualenv != null and virtualenv.?.len > 0) {
        print_path = PrintPath{
            .pointer = virtualenv,
        };
        info.path = print_path;
        info.color = blue.?;
        info.is_virtualenv_path = true;
        print("{s}", .{" ("});
        try print_shortened_path(info);
        print("{s}", .{")"});
    }

    print("{s}", .{"\n$ "});

    if (info.not_host_env != null) {
        if (std.mem.eql(u8, info.not_host_env.?, "")) {
            try update_tmp_bash_env_content(os_cloud, kubeconfig);
        }
    }
}
