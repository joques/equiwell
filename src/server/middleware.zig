const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const JwtManager = @import("../auth/jwt.zig").JwtManager;
const Rbac = @import("../auth/rbac.zig").Rbac;
const UserRole = @import("../models/user.zig").UserRole;

/// Middleware execution pipeline.
pub const Middleware = struct {
    jwt_mgr: JwtManager,

    pub fn init(jwt_mgr: JwtManager) Middleware {
        return .{ .jwt_mgr = jwt_mgr };
    }

    /// Authenticates incoming request by parsing Bearer JWT token in Authorization header.
    pub fn authenticate(self: Middleware, req: *Request) void {
        var lines = std.mem.splitSequence(u8, req.headers, "\r\n");
        while (lines.next()) |line| {
            if (std.ascii.startsWithIgnoreCase(line, "authorization:")) {
                const header_val = std.mem.trim(u8, line[14..], " \t");
                if (Rbac.extractBearerToken(header_val)) |token_str| {
                    req.user = self.jwt_mgr.verifyToken(req.allocator, token_str);
                }
                break;
            }
        }
    }

    /// Enforces required authentication.
    pub fn requireAuth(req: *const Request, res: *const Response) !bool {
        if (req.user == null) {
            try res.unauthorized("Authentication token required.");
            return false;
        }
        return true;
    }

    /// Enforces admin role access.
    pub fn requireAdmin(req: *const Request, res: *const Response) !bool {
        if (!try requireAuth(req, res)) return false;
        if (!Rbac.isAdmin(req.user.?)) {
            try res.forbidden("Administrator privileges required.");
            return false;
        }
        return true;
    }

    /// Enforces non-viewer role access.
    pub fn requireNonViewer(req: *const Request, res: *const Response) !bool {
        if (!try requireAuth(req, res)) return false;
        if (!Rbac.isNonViewer(req.user.?)) {
            try res.forbidden("Read-only viewers cannot perform this operation.");
            return false;
        }
        return true;
    }
};
