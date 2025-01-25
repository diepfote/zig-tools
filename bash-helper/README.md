# Bash PS1 helper

## Build instructions


```
zig build-exe -O ReleaseFast  main.zig
```

### Debug

This enables debug prints as well

```
zig build-exe -O Debug  main.zig
```

### For a specific architecture

```text
# e.g. for lima vm prompts 
zig build-exe -O ReleaseFast -target x86_64-linux-gnu -femit-bin=main-linux main.zig
```
