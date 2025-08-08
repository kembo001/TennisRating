const sqlite3 = require('sqlite3').verbose();
const path = require('path');

class Database {
    constructor() {
        const dbPath = process.env.DATABASE_URL || './tennis_rating.db';
        this.db = new sqlite3.Database(dbPath, (err) => {
            if (err) {
                console.error('❌ Error opening database:', err.message);
            } else {
                console.log('✅ Connected to SQLite database');
                this.init();
            }
        });
    }

    init() {
        // Enable foreign keys
        this.db.run("PRAGMA foreign_keys = ON");
        
        this.createTables();
    }

    createTables() {
        // Users table
        const createUsersTable = `
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                email TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        `;

        // Sessions table - stores tennis session data
        const createSessionsTable = `
            CREATE TABLE IF NOT EXISTS sessions (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                total_shots INTEGER NOT NULL,
                successful_shots INTEGER NOT NULL,
                timestamp DATETIME NOT NULL,
                session_duration REAL NOT NULL,
                forehand_count INTEGER DEFAULT 0,
                backhand_count INTEGER DEFAULT 0,
                serve_count INTEGER DEFAULT 0,
                shot_timings TEXT, -- JSON array of shot timing intervals
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            )
        `;

        // Create indexes for better performance
        const createIndexes = [
            'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
            'CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id)',
            'CREATE INDEX IF NOT EXISTS idx_sessions_timestamp ON sessions(timestamp)'
        ];

        // Execute table creation
        this.db.serialize(() => {
            this.db.run(createUsersTable, (err) => {
                if (err) {
                    console.error('❌ Error creating users table:', err.message);
                } else {
                    console.log('✅ Users table ready');
                }
            });

            this.db.run(createSessionsTable, (err) => {
                if (err) {
                    console.error('❌ Error creating sessions table:', err.message);
                } else {
                    console.log('✅ Sessions table ready');
                }
            });

            // Create indexes
            createIndexes.forEach((indexQuery) => {
                this.db.run(indexQuery, (err) => {
                    if (err) {
                        console.error('❌ Error creating index:', err.message);
                    }
                });
            });
        });
    }

    // Generic query methods
    get(query, params = []) {
        return new Promise((resolve, reject) => {
            this.db.get(query, params, (err, result) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(result);
                }
            });
        });
    }

    all(query, params = []) {
        return new Promise((resolve, reject) => {
            this.db.all(query, params, (err, rows) => {
                if (err) {
                    reject(err);
                } else {
                    resolve(rows);
                }
            });
        });
    }

    run(query, params = []) {
        return new Promise((resolve, reject) => {
            this.db.run(query, params, function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve({
                        id: this.lastID,
                        changes: this.changes
                    });
                }
            });
        });
    }

    // User-specific queries
    async createUser(id, email, name, passwordHash) {
        const query = `
            INSERT INTO users (id, email, name, password_hash)
            VALUES (?, ?, ?, ?)
        `;
        return await this.run(query, [id, email, name, passwordHash]);
    }

    async getUserByEmail(email) {
        const query = 'SELECT * FROM users WHERE email = ?';
        return await this.get(query, [email]);
    }

    async getUserById(id) {
        const query = 'SELECT * FROM users WHERE id = ?';
        return await this.get(query, [id]);
    }

    // Session-specific queries
    async createSession(sessionData) {
        const query = `
            INSERT INTO sessions (
                id, user_id, total_shots, successful_shots, 
                timestamp, session_duration, forehand_count, 
                backhand_count, serve_count, shot_timings
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `;
        
        const params = [
            sessionData.id,
            sessionData.user_id,
            sessionData.total_shots,
            sessionData.successful_shots,
            sessionData.timestamp,
            sessionData.session_duration,
            sessionData.forehand_count,
            sessionData.backhand_count,
            sessionData.serve_count,
            JSON.stringify(sessionData.shot_timings)
        ];

        return await this.run(query, params);
    }

    async getUserSessions(userId, limit = 50, offset = 0) {
        const query = `
            SELECT * FROM sessions 
            WHERE user_id = ? 
            ORDER BY timestamp DESC 
            LIMIT ? OFFSET ?
        `;
        const sessions = await this.all(query, [userId, limit, offset]);
        
        // Parse shot_timings JSON back to array
        return sessions.map(session => ({
            ...session,
            shot_timings: JSON.parse(session.shot_timings || '[]')
        }));
    }

    async getSessionById(sessionId) {
        const query = 'SELECT * FROM sessions WHERE id = ?';
        const session = await this.get(query, [sessionId]);
        
        if (session && session.shot_timings) {
            session.shot_timings = JSON.parse(session.shot_timings);
        }
        
        return session;
    }

    // Stats calculations
    async getUserStats(userId) {
        const statsQuery = `
            SELECT 
                COUNT(*) as total_sessions,
                SUM(total_shots) as total_shots,
                SUM(successful_shots) as total_successful_shots,
                AVG(CAST(successful_shots AS FLOAT) / total_shots * 100) as avg_success_rate,
                MAX(CAST(successful_shots AS FLOAT) / total_shots * 100) as best_success_rate,
                SUM(forehand_count) as total_forehand,
                SUM(backhand_count) as total_backhand,
                SUM(serve_count) as total_serves,
                AVG(session_duration) as avg_duration
            FROM sessions 
            WHERE user_id = ?
        `;
        
        return await this.get(statsQuery, [userId]);
    }

    async getUserProgressData(userId, days = 30) {
        const query = `
            SELECT 
                DATE(timestamp) as date,
                COUNT(*) as sessions_count,
                AVG(CAST(successful_shots AS FLOAT) / total_shots * 100) as avg_rating,
                SUM(total_shots) as total_shots
            FROM sessions 
            WHERE user_id = ? 
            AND timestamp >= datetime('now', '-${days} days')
            GROUP BY DATE(timestamp)
            ORDER BY date DESC
        `;
        
        return await this.all(query, [userId]);
    }

    // Close database connection
    close() {
        return new Promise((resolve, reject) => {
            this.db.close((err) => {
                if (err) {
                    reject(err);
                } else {
                    console.log('✅ Database connection closed');
                    resolve();
                }
            });
        });
    }
}

// Singleton instance
let dbInstance = null;

function getDatabase() {
    if (!dbInstance) {
        dbInstance = new Database();
    }
    return dbInstance;
}

module.exports = getDatabase;