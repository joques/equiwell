const std = @import("std");

/// Standardized API error categories across the EquiWell platform.
pub const ApiError = error{
    BadRequest,
    Unauthorized,
    Forbidden,
    NotFound,
    Conflict,
    UnprocessableEntity,
    InternalServerError,
    ServiceUnavailable,
    DatabaseError,
    InvalidToken,
    ExpiredToken,
    UserNotFound,
    BoreholeNotFound,
    ResourceNotFound,
};

/// Structured API Error descriptor containing machine-readable code, HTTP status, and message.
pub const ErrorResponse = struct {
    status_code: u16,
    code: []const u8,
    message: []const u8,
    request_id: ?[]const u8 = null,

    /// Maps standard ApiError variants to HTTP status code and machine error code.
    pub fn fromApiError(err: ApiError, message: []const u8, request_id: ?[]const u8) ErrorResponse {
        const status_code: u16 = switch (err) {
            error.BadRequest => 400,
            error.Unauthorized, error.InvalidToken, error.ExpiredToken => 401,
            error.Forbidden => 403,
            error.NotFound, error.UserNotFound, error.BoreholeNotFound, error.ResourceNotFound => 404,
            error.Conflict => 409,
            error.UnprocessableEntity => 422,
            error.ServiceUnavailable => 503,
            error.InternalServerError, error.DatabaseError => 500,
        };

        const code: []const u8 = switch (err) {
            error.BadRequest => "BAD_REQUEST",
            error.Unauthorized, error.InvalidToken, error.ExpiredToken => "UNAUTHORIZED",
            error.Forbidden => "FORBIDDEN",
            error.NotFound, error.UserNotFound, error.BoreholeNotFound, error.ResourceNotFound => "NOT_FOUND",
            error.Conflict => "CONFLICT",
            error.UnprocessableEntity => "UNPROCESSABLE_ENTITY",
            error.ServiceUnavailable => "SERVICE_UNAVAILABLE",
            error.InternalServerError, error.DatabaseError => "INTERNAL_SERVER_ERROR",
        };

        return .{
            .status_code = status_code,
            .code = code,
            .message = message,
            .request_id = request_id,
        };
    }

    /// Serializes error descriptor to clean JSON string format.
    pub fn toJson(self: ErrorResponse, allocator: std.mem.Allocator) ![]const u8 {
        if (self.request_id) |rid| {
            return std.fmt.allocPrint(allocator,
                "{{\"error\":{{\"code\":\"{s}\",\"message\":\"{s}\",\"request_id\":\"{s}\"}}}}",
                .{ self.code, self.message, rid }
            );
        } else {
            return std.fmt.allocPrint(allocator,
                "{{\"error\":{{\"code\":\"{s}\",\"message\":\"{s}\"}}}}",
                .{ self.code, self.message }
            );
        }
    }
};
