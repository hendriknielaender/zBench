## Install 

You can use `zig fetch` to conveniently set the hash in the `build.zig.zon` file and update an existing dependency.

Run the following command to fetch the zBench package:
```shell
zig fetch https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz --save
```
Using `zig fetch` simplifies managing dependencies by automatically handling the package hash, ensuring your `build.zig.zon` file is up to date.

### Option 1 (build.zig.zon)

1. Declare zBench as a dependency in `build.zig.zon`:

   ```diff
   .{
       .name = "my-project",
       .version = "1.0.0",
       .paths = .{""},
       .dependencies = .{
   +       .zbench = .{
   +           .url = "https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz",
   +       },
       },
   }
   ```

2. Add the module in `build.zig`:

   ```diff
   const std = @import("std");

   pub fn build(b: *std.Build) void {
       const target = b.standardTargetOptions(.{});
       const optimize = b.standardOptimizeOption(.{});

   +   const opts = .{ .target = target, .optimize = optimize };
   +   const zbench_module = b.dependency("zbench", opts).module("zbench");

       const exe = b.addExecutable(.{
           .name = "test",
           .root_source_file = b.path("src/main.zig"),
           .target = target,
           .optimize = optimize,
       });
   +   exe.root_module.addImport("zbench", zbench_module);
       exe.install();

       ...
   }
   ```

3. Get the package hash:

   ```shell
   $ zig build
   my-project/build.zig.zon:6:20: error: url field is missing corresponding hash field
           .url = "https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz",
                  ^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   note: expected .hash = "<HASH>",
   ```

4. Update `build.zig.zon` package hash value:

   ```diff
   .{
       .name = "my-project",
       .version = "1.0.0",
       .paths = .{""},
       .dependencies = .{
           .zbench = .{
               .url = "https://github.com/hendriknielaender/zbench/archive/<COMMIT>.tar.gz",
   +           .hash = "<HASH>",
           },
       },
   }
   ```

### Option 2 (git submodule)

On your project root directory make a directory name libs.

- Run `git submodule add https://github.com/hendriknielaender/zBench libs/zbench`
- Then add the module into your `build.zig`

```zig
exe.root_module.addAnonymousImport("zbench", .{
    .root_source_file = b.path("libs/zbench/zbench.zig"),
});
```

Now you can import like this:

```zig
const zbench = @import("zbench");
```

## Further Reading

For more information on the Zig build system and useful tricks, check out these resources:

- [Zig Build System](https://ziglang.org/learn/build-system/)
- [Build System Tricks](https://ziggit.dev/t/build-system-tricks/)
