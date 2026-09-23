const std = @import("std");

/// Cross-Origin Resource Sharing (CORS) header provider and pre-flight handling.
pub const Cors = struct {
    pub const headers =
        "Access-Control-Allow-Origin: *\r\n" ++
        "Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\n" ++
        "Access-Control-Allow-Headers: Content-Type, Authorization\r\n";
};
