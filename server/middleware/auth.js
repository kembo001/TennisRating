const jwt = require('jsonwebtoken');
const getDatabase = require('../database');

// JWT utility functions
const generateToken = (userId) => {
    return jwt.sign(
        { userId }, 
        process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production',
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
};

const verifyToken = (token) => {
    try {
        return jwt.verify(token, process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production');
    } catch (error) {
        return null;
    }
};

// Middleware to authenticate JWT tokens
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({
            success: false,
            error: 'Access token required'
        });
    }

    const decoded = verifyToken(token);
    if (!decoded) {
        return res.status(401).json({
            success: false,
            error: 'Invalid or expired token'
        });
    }

    try {
        // Verify user still exists in database
        const db = getDatabase();
        const user = await db.getUserById(decoded.userId);
        
        if (!user) {
            return res.status(401).json({
                success: false,
                error: 'User no longer exists'
            });
        }

        // Attach user info to request
        req.user = {
            id: user.id,
            email: user.email,
            name: user.name
        };

        next();
    } catch (error) {
        console.error('Auth middleware error:', error);
        res.status(500).json({
            success: false,
            error: 'Authentication error'
        });
    }
};

// Optional middleware - doesn't fail if no token
const optionalAuth = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return next(); // Continue without user
    }

    const decoded = verifyToken(token);
    if (!decoded) {
        return next(); // Continue without user
    }

    try {
        const db = getDatabase();
        const user = await db.getUserById(decoded.userId);
        
        if (user) {
            req.user = {
                id: user.id,
                email: user.email,
                name: user.name
            };
        }
    } catch (error) {
        console.error('Optional auth error:', error);
        // Continue anyway
    }

    next();
};

module.exports = {
    generateToken,
    verifyToken,
    authenticateToken,
    optionalAuth
};