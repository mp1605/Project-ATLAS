# Readiness Backend

Secure backend API for Military Readiness App - Accepts **ONLY** calculated scores, **NEVER** raw HealthKit data.

## Features

- ✅ JWT-based authentication (DEVICE & ADMIN roles)
- ✅ Strict payload validation
- ✅ Rejects raw HealthKit data
- ✅ Rate limiting
- ✅ CORS protection
- ✅ Helmet security
- ✅ Request logging

## Privacy Guarantee

This backend **REJECTS** any payloads containing:
- Raw heart rate measurements
- Sleep stage timestamps
- Step counts per minute
- ECG data
- GPS coordinates
- Nutrition logs

**Only aggregated scores** (0-100 range) are accepted.

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Run development server:**
   ```bash
   npm run dev
   ```

4. **Build for production:**
   ```bash
   npm run build
   npm start
   ```

## API Endpoints

### Authentication

- `POST /api/v1/auth/register` - Register new user (DEVICE or ADMIN)
- `POST /api/v1/auth/login` - Login and get JWT token

### Readiness Scores

- `POST /api/v1/readiness` - Submit scores (DEVICE role, requires auth)
- `GET /api/v1/readiness/:userId/latest` - Get latest scores (ADMIN role)
- `GET /api/v1/readiness/:userId/history?days=30` - Get history (ADMIN role)
- `GET /api/v1/readiness/users` - List all users (ADMIN role)

## Example Usage

### 1. Register Device
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "device@example.com",
    "password": "secure-password",
    "role": "DEVICE"
  }'
```

### 2. Submit Scores
```bash
curl -X POST http://localhost:3000/api/v1/readiness \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "user_id": "user@example.com",
    "timestamp": "2026-01-18T00:00:00Z",
    "scores": {
      "readiness": 85.3,
      "fatigue_index": 72.1,
      ...
    },
    "category": "GO",
    "confidence": "high"
  }'
```

### 3. Get Latest Scores (Admin)
```bash
curl http://localhost:3000/api/v1/readiness/user@example.com/latest \
  -H "Authorization: Bearer ADMIN_TOKEN"
```

## Deployment

### Render / Railway / Fly.io

1. Connect GitHub repository
2. Set environment variables
3. Deploy automatically on push to main

### Manual Deployment

```bash
npm run build
NODE_ENV=production npm start
```

## Security Notes

- Change `JWT_SECRET` in production
- Use HTTPS only
- Enable rate limiting
- Set `REJECT_RAW_HEALTH_DATA=true`
- Monitor rejected payloads

## License

MIT
