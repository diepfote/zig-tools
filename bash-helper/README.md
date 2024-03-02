# Bash PS1 helper

## Build instructions

```text
# -lc  ... use libc
# -I   ... add include path -> spin_off.c
zig build-exe -O ReleaseFast -lc -I c-src/ main.zig
```

For a specific architecture

```text
# e.g. for lima vm prompts 
zig build-exe -O ReleaseFast -lc -I c-src/ -target x86_64-linux-gnu -femit-bin=main-linux main.zig
```
