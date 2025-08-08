const express = require('express');
const getDatabase = require('../database');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// Calculate rating based on session data (matches iOS app logic)
const calculateRating = (session) => {
  const successRate = session.total_shots > 0 ? 
    (session.successful_shots / session.total_shots) : 0;
  
  // Parse shot timings for consistency calculation
  let consistencyRating = 0;
  if (session.shot_timings && session.shot_timings.length > 1) {
    const timings = session.shot_timings;
    const avg = timings.reduce((sum, t) => sum + t, 0) / timings.length;
    const variance = timings.reduce((sum, t) => sum + Math.pow(t - avg, 2), 0) / timings.length;
    const stdDev = Math.sqrt(variance);
    consistencyRating = Math.max(0, 1 - (stdDev / avg));
  }

  const successScore = successRate * 50;
  const consistencyScore = consistencyRating * 30;
  const volumeScore = Math.min(session.total_shots / 50.0, 1.0) * 20;
  
  const totalScore = successScore + consistencyScore + volumeScore;
  
  if (totalScore >= 80) return 5;
  if (totalScore >= 60) return 4;
  if (totalScore >= 40) return 3;
  if (totalScore >= 20) return 2;
  return 1;
};

// Calculate improvement trend from recent sessions
const calculateImprovementTrend = (sessions) => {
  if (sessions.length < 2) return 0;
  
  // Get ratings for recent sessions
  const ratings = sessions.slice(0, Math.min(10, sessions.length)).map(calculateRating);
  
  if (ratings.length < 2) return 0;
  
  // Simple linear trend calculation
  const firstHalf = ratings.slice(0, Math.floor(ratings.length / 2));
  const secondHalf = ratings.slice(Math.floor(ratings.length / 2));
  
  const firstAvg = firstHalf.reduce((sum, r) => sum + r, 0) / firstHalf.length;
  const secondAvg = secondHalf.reduce((sum, r) => sum + r, 0) / secondHalf.length;
  
  return secondAvg - firstAvg;
};

// GET /api/stats/:userId - Get user statistics
router.get('/:userId', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Users can only access their own stats
    if (req.user.id !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Access denied. You can only view your own statistics.'
      });
    }

    const db = getDatabase();
    
    // Get basic stats from database
    const basicStats = await db.getUserStats(userId);
    
    // Get recent sessions for more detailed calculations
    const recentSessions = await db.getUserSessions(userId, 20, 0);
    
    // Calculate ratings for each session
    const sessionsWithRatings = recentSessions.map(session => ({
      ...session,
      rating: calculateRating(session)
    }));
    
    // Calculate average and best ratings
    const ratings = sessionsWithRatings.map(s => s.rating);
    const averageRating = ratings.length > 0 ? 
      ratings.reduce((sum, r) => sum + r, 0) / ratings.length : 0;
    const bestRating = ratings.length > 0 ? Math.max(...ratings) : 0;
    
    // Calculate improvement trend
    const improvementTrend = calculateImprovementTrend(sessionsWithRatings);
    
    // Prepare recent activity (last 5 sessions)
    const recentActivity = recentSessions.slice(0, 5).map(session => ({
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

    const stats = {
      totalSessions: basicStats?.total_sessions || 0,
      totalShots: basicStats?.total_shots || 0,
      averageRating: Math.round(averageRating * 100) / 100, // Round to 2 decimal places
      bestRating: bestRating,
      improvementTrend: Math.round(improvementTrend * 100) / 100,
      swingBreakdown: {
        forehand: basicStats?.total_forehand || 0,
        backhand: basicStats?.total_backhand || 0,
        serve: basicStats?.total_serves || 0
      },
      recentActivity: recentActivity
    };

    res.json({
      success: true,
      stats: stats
    });

  } catch (error) {
    console.error('Stats calculation error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to calculate statistics'
    });
  }
});

// GET /api/stats/:userId/progress - Get progress over time
router.get('/:userId/progress', authenticateToken, async (req, res) => {
  try {
    const { userId } = req.params;
    const { period } = req.query; // 'week', 'month', 'year'
    
    // Users can only access their own progress
    if (req.user.id !== userId) {
      return res.status(403).json({
        success: false,
        error: 'Access denied. You can only view your own progress.'
      });
    }

    // Determine number of days based on period
    let days = 30; // Default month
    switch (period) {
      case 'week':
        days = 7;
        break;
      case 'month':
        days = 30;
        break;
      case 'year':
        days = 365;
        break;
      default:
        days = 30;
    }

    const db = getDatabase();
    const progressData = await db.getUserProgressData(userId, days);
    
    // Transform data for chart display
    const dataPoints = progressData.map(point => ({
      date: point.date,
      rating: Math.round(point.avg_rating * 100) / 100,
      shots: point.total_shots,
      sessionsCount: point.sessions_count
    }));

    res.json({
      success: true,
      progress: {
        period: period || 'month',
        dataPoints: dataPoints
      }
    });

  } catch (error) {
    console.error('Progress data error:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch progress data'
    });
  }
});

module.exports = router;