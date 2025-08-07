# Tennis Rating - Development Coordination

## Team Roles
- **Reid (Backend)**: Node.js/Express server, API endpoints, database
- **Brandon (Frontend)**: iOS Swift app, UI/UX, computer vision integration

## Current Status ✅
- [x] Server structure created with Express.js
- [x] API routes defined (placeholder responses)
- [x] iOS app with advanced computer vision working
- [x] Monorepo structure established

## API Endpoints Ready for Frontend Integration

### Authentication
```
POST /api/auth/register
POST /api/auth/login  
POST /api/auth/logout
```

### Session Data
```
POST /api/sessions           # Upload tennis session
GET /api/sessions/:userId    # Get user's session history
GET /api/sessions/session/:sessionId  # Get specific session
```

### Statistics  
```
GET /api/stats/:userId       # Get user statistics
GET /api/stats/:userId/progress  # Get progress over time
```

### Health Check
```
GET /health                  # Server status
```

## Brandon's Frontend Tasks

### 1. Network Layer (Priority 1)
- [ ] Create `APIClient.swift` class for HTTP requests
- [ ] Add network error handling
- [ ] Implement base URL configuration (point to Reid's server)
- [ ] Add request/response logging for debugging

### 2. User Authentication (Priority 2)
- [ ] Create login/register screens
- [ ] Implement JWT token storage (Keychain)
- [ ] Add authentication state management
- [ ] Handle token refresh/expiry

### 3. Session Upload (Priority 3)
- [ ] Convert `SessionData` model to JSON
- [ ] Upload session after practice completion
- [ ] Add upload progress indicator  
- [ ] Handle upload failures with retry logic

### 4. Session History (Priority 4)
- [ ] Create session history view
- [ ] Display past sessions with ratings
- [ ] Add pull-to-refresh functionality
- [ ] Show session details (swing breakdown, etc.)

### 5. Statistics Dashboard (Priority 5)
- [ ] Progress charts and graphs
- [ ] Personal best tracking
- [ ] Improvement trends over time
- [ ] Swing type analytics

## Reid's Backend Tasks

### 1. Database Setup (Priority 1)
- [ ] Set up SQLite database
- [ ] Create user table schema
- [ ] Create sessions table schema
- [ ] Add database connection and migrations

### 2. Authentication Implementation (Priority 2)
- [ ] Hash password with bcryptjs
- [ ] Generate/verify JWT tokens
- [ ] Add authentication middleware
- [ ] Implement user registration/login logic

### 3. Session Storage (Priority 3)
- [ ] Parse and validate session JSON
- [ ] Store session data in database
- [ ] Add session retrieval queries
- [ ] Implement user-specific data isolation

### 4. Statistics Engine (Priority 4)
- [ ] Calculate user statistics from sessions
- [ ] Generate progress data over time
- [ ] Add caching for expensive queries
- [ ] Create analytics aggregations

### 5. Production Deployment (Priority 5)
- [ ] Set up PM2 process management
- [ ] Configure nginx reverse proxy
- [ ] Add SSL certificate
- [ ] Set up monitoring and logging

## Server Information
- **Development URL**: `http://YOUR_DIGITAL_OCEAN_IP:3000`
- **Health Check**: `GET /health`
- **Current Status**: Placeholder responses (JSON structure ready)

## Getting Started

### Brandon - iOS Development
1. Update iOS app to point to Reid's server URL
2. Start with authentication flow first
3. Test against placeholder API responses
4. Real data will work automatically once Reid implements backend

### Reid - Backend Development  
1. `cd server && npm install`
2. `cp .env.example .env` (configure settings)
3. `npm run dev` (start development server)
4. Implement database layer first, then authentication

## Communication
- Use GitHub issues for bugs/features
- Update this file as tasks are completed
- Test integration frequently as both sides develop

## Example API Usage for Brandon

### Login Request
```swift
let loginData = ["email": "user@test.com", "password": "password123"]
// POST to /api/auth/login
// Response: { "success": true, "token": "jwt-token", "user": {...} }
```

### Upload Session
```swift
let sessionJSON = try JSONEncoder().encode(sessionData)
// POST to /api/sessions
// Response: { "success": true, "sessionId": "abc123" }
```

---
*Last updated: $(date)*
*Next sync: Weekly check-ins on progress*