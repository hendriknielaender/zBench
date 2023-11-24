const std = @import("std");

/// Timer tracks the time based on Unix timestamps obtained from
/// std.time.nanoTimestamp, which returns an i128 - which in turn is casted to a u64;
/// - assuming no machine that runs this code has its clock set pre-Unix epoch, casting to unsigned should be safe
/// - it will overflow in April of the year 2262, so some time to refactor if needed
pub const Timer = struct {
    startTime: u64 = 0,
    elapsedTime: u64 = 0,

    pub fn start(self: *Timer) void {
        self.startTime = @intCast(std.time.nanoTimestamp());
    }

    pub fn stop(self: *Timer) void {
        if (self.startTime != 0) {
            const stamp: u64 = @intCast(std.time.nanoTimestamp());
            self.elapsedTime = stamp - self.startTime;
        }
        self.startTime = 0;
    }

    pub fn elapsed(self: Timer) u64 {
        if (self.startTime == 0) {
            return self.elapsedTime;
        } else {
            const stamp: u64 = @intCast(std.time.nanoTimestamp());
            return stamp - self.startTime;
        }
    }

    pub fn reset(self: *Timer) void {
        self.startTime = @intCast(std.time.nanoTimestamp());
    }
};
