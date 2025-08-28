// Root entry point - re-exports src/zbench.zig for backward compatibility
pub const zbench = @import("src/zbench.zig");

pub const Benchmark = zbench.Benchmark;
pub const Config = zbench.Config;
pub const Hooks = zbench.Hooks;
pub const Definition = zbench.Definition;
pub const BenchFunc = zbench.BenchFunc;
pub const ParameterisedFunc = zbench.ParameterisedFunc;
pub const Result = zbench.Result;
pub const statistics = zbench.statistics;
pub const prettyPrintHeader = zbench.prettyPrintHeader;
pub const getSystemInfo = zbench.getSystemInfo;
