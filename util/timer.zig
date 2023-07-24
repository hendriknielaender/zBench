const std = @import("std");

pub const Timer = struct {
    startTime: u64 = 0,
    elapsedTime: u64 = 0,

    pub fn start(self: *Timer) void {
        self.startTime = @intCast(std.time.microTimestamp());
    }

    pub fn stop(self: *Timer) void {
        if (self.startTime != 0) {
            var stamp: u64 = @intCast(std.time.microTimestamp());
            self.elapsedTime = stamp - self.startTime;
        }
        self.startTime = 0;
    }

    pub fn elapsed(self: Timer) u64 {
        if (self.startTime == 0) {
            return self.elapsedTime;
        } else {
            var stamp: u64 = @intCast(std.time.microTimestamp());
            return stamp - self.startTime;
        }
    }

    pub fn reset(self: *Timer) void {
        self.startTime = @intCast(std.time.microTimestamp());
    }
};
