const std = @import("std");
const zbench = @import("zbench");

fn myFunction() void {
    var sum: usize = 0;
    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        sum += 1;
    }
}

fn myFunction2() void {
    var sum: usize = 0;
    var i: usize = 0;
    while (i < 100000) : (i += 1) {
        sum += 1;
    }
}

pub fn main() void {
    zbench.benchmark(myFunction, "myFunction");
    zbench.benchmark(myFunction2, "myFunction2");
}
