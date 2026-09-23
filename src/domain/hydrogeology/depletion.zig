const std = @import("std");

pub const DepletionSimulation = struct {
    sustainability_status: []const u8,
    depletion_risk_level: []const u8,
    estimated_annual_drawdown_m: f64,
    recharge_replenishment_rate: []const u8,

    pub fn simulate(daily_extraction_liters: u64, horizon_years: u16) DepletionSimulation {
        _ = horizon_years;
        if (daily_extraction_liters <= 30000) {
            return .{
                .sustainability_status = "sustainable",
                .depletion_risk_level = "low",
                .estimated_annual_drawdown_m = 0.35,
                .recharge_replenishment_rate = "high_seasonal",
            };
        } else {
            return .{
                .sustainability_status = "at_risk",
                .depletion_risk_level = "high",
                .estimated_annual_drawdown_m = 1.85,
                .recharge_replenishment_rate = "insufficient",
            };
        }
    }
};
