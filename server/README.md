# Tennis Rating Server

Node.js backend API for the Tennis Rating iOS app.

## Setup

1. Install dependencies:
```bash
cd server
npm install
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your settings
```

3. Start development server:
```bash
npm run dev
```

## API Endpoints

### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout

### Sessions
- `POST /api/sessions` - Upload session data
- `GET /api/sessions/:userId` - Get user's sessions
- `GET /api/sessions/session/:sessionId` - Get specific session

### Statistics
- `GET /api/stats/:userId` - Get user statistics
- `GET /api/stats/:userId/progress` - Get progress over time

### Health
- `GET /health` - Server health check

## Production Deployment

Use PM2 for process management:
```bash
pm2 start index.js --name tennis-api
pm2 save
pm2 startup
```

## Database

Currently configured for SQLite for simplicity. Schema and models will be added as needed.