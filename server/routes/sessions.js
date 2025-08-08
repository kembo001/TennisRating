const express = require('express');
const { v4: uuidv4 } = require('uuid');
const getDatabase = require('../database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Session data validation
const validateSessionData = (sessionData) => {
  const required = ['totalShots', 'successfulShots', 'timestamp', 'sessionDuration', 'shotTimings'];
  const missing = required.filter(field => sessionData[field] === undefined);
  
  if (missing.length > 0) {
    return `Missing required fields: ${missing.join(', ')}`;
  }

  if (sessionData.totalShots < 0 || sessionData.successfulShots < 0) {
    return 'Shot counts cannot be negative';
  }

  if (sessionData.successfulShots > sessionData.totalShots) {
    return 'Successful shots cannot exceed total shots';
  }

  if (sessionData.sessionDuration <= 0) {
    return 'Session duration must be positive';
  }

  if (!Array.isArray(sessionData.shotTimings)) {
    return 'Shot timings must be an array';
  }

  return null; // Valid
};

// POST /api/sessions - Upload a tennis session
router.post('/', authenticateToken, async (req, res) => {
  try {
    const sessionData = req.body;
    const userId = req.user.id;

    // Validate session data
    const validationError = validateSessionData(sessionData);
    if (validationError) {
      return res.status(400).json({
        success: false,
        error: validationError
      });
    }

    // Prepare session for database
    const sessionId = uuidv4();
    const dbSessionData = {
      id: sessionId,
      user_id: userId,
      total_shots: sessionData.totalShots,
      successful_shots: sessionData.successfulShots,
      timestamp: new Date(sessionData.timestamp).toISOString(),
      session_duration: sessionData.sessionDuration,
      forehand_count: sessionData.forehandCount || 0,
      backhand_count: sessionData.backhandCount || 0,
      serve_count: sessionData.serveCount || 0,
      shot_timings: sessionData.shotTimings || []
    };

    // Save to database
    const db = getDatabase();
    await db.createSession(dbSessionData);

    console.log(`✅ Session uploaded for user ${req.user.email}: ${sessionId}`);

    res.status(201).json({
      success: true,
      message: 'Session uploaded successfully',
      sessionId: sessionId
    });

  } catch (error) {
    console.error('Session upload error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to save session. Please try again.'
    });
  }
});

// GET /api/sessions/:userId - Get user's session history
router.get('/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Users can only access their own sessions
    if (req.user.id !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Access denied. You can only view your own sessions.'
      });
    }

    // Get pagination parameters
    const limit = Math.min(parseInt(req.query.limit) || 50, 100); // Max 100 sessions
    const offset = parseInt(req.query.offset) || 0;

    const db = getDatabase();
    const sessions = await db.getUserSessions(userId, limit, offset);

    // Transform database format back to app format
    const transformedSessions = sessions.map(session => ({
      id: session.id,
      totalShots: session.total_shots,
      successfulShots: session.successful_shots,
      timestamp: new Date(session.timestamp),
      sessionDuration: session.session_duration,
      forehandCount: session.forehand_count,
      backhandCount: session.backhand_count,
      serveCount: session.serve_count,
      shotTimings: session.shot_timings
    }));

    res.json({
      success: true,
      sessions: transformedSessions,
      pagination: {
        limit,
        offset,
        total: transformedSessions.length
      }
    });

  } catch (error) {
    console.error('Fetch sessions error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch sessions'
    });
  }
});

// GET /api/sessions/session/:sessionId - Get specific session details
router.get('/session/:sessionId', authenticateToken, async (req, res) => {
  try {
    const { sessionId } = req.params;

    const db = getDatabase();
    const session = await db.getSessionById(sessionId);

    if (!session) {
      return res.status(404).json({
        success: false,
        error: 'Session not found'
      });
    }

    // Check if user owns this session
    if (session.user_id !== req.user.id) {
      return res.status(403).json({
        success: false,
        error: 'Access denied. You can only view your own sessions.'
      });
    }

    // Transform to app format
    const transformedSession = {
      id: session.id,
      totalShots: session.total_shots,
      successfulShots: session.successful_shots,
      timestamp: new Date(session.timestamp),
      sessionDuration: session.session_duration,
      forehandCount: session.forehand_count,
      backhandCount: session.backhand_count,
      serveCount: session.serve_count,
      shotTimings: session.shot_timings
    };

    res.json({
      success: true,
      session: transformedSession
    });

  } catch (error) {
    console.error('Fetch session error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch session'
    });
  }
});

module.exports = router;