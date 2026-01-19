# Production Deployment Guide

## Quick Deploy Checklist

### ☐ 1. Deploy Backend to Render.com

1. **Create account:** https://render.com
2. **New Web Service** → Connect GitHub repo
3. **Settings:**
   - Build Command: `npm install && npm run build`
   - Start Command: `npm start`
   - Environment: Node 20.x

4. **Environment Variables:**
   ```
   NODE_ENV=production
   JWT_SECRET=<generate-with: node -e "console.log(require('crypto').randomBytes(32).toString('hex'))">
   CORS_ORIGINS=https://your-dashboard-domain.com
   REJECT_RAW_HEALTH_DATA=true
   LOG_REJECTED_PAYLOADS=true
   ```

5. **Deploy** → Copy the URL (e.g., `https://readiness-api.onrender.com`)

### ☐ 2. Update Mobile App

**File:** `lib/services/all_scores_calculator.dart`

Change line 267:
```dart
baseUrl: 'https://readiness-api.onrender.com', // Production URL
```

**Build:**
```bash
cd mil_readiness_app
flutter build ios --release
# Upload to App Store Connect
```

### ☐ 3. Deploy Dashboard

1. **Update API URL** in `public/js/readiness-scores.js`:
   ```javascript
   const API_BASE_URL = 'https://readiness-api.onrender.com';
   ```

2. **Deploy to Netlify:**
   - Drag & drop `Dasboard  ` folder to Netlify
   - Copy dashboard URL
   - Add to backend CORS_ORIGINS

### ☐ 4. Re-Enable Authentication (Production Security)

**File:** `readiness-backend/src/routes/readiness.ts`

Restore authentication on lines 84, 109, 145:
```typescript
router.get('/:userId/latest', authenticate, requireRole('ADMIN'), async (...) => {
router.get('/:userId/history', authenticate, requireRole('ADMIN'), async (...) => {
router.get('/users', authenticate, requireRole('ADMIN'), async (...) => {
```

### ☐ 5. Create Admin User

```bash
curl -X POST https://readiness-api.onrender.com/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email":"admin@yourdomain.com",
    "password":"<secure-password>",
    "role":"ADMIN"
  }'
```

Save the returned token for dashboard.

### ☐ 6. Update Dashboard with Admin Token

**File:** `public/js/readiness-scores.js` (line 58)

```javascript
headers: {
  'Content-Type': 'application/json',
  'Authorization': `Bearer <admin-token-from-step-5>`
}
```

---

## Verification

✅ Mobile app sends scores to production backend  
✅ Dashboard fetches from production backend  
✅ Authentication required for dashboard  
✅ CORS working (dashboard can fetch)  
✅ HTTPS enabled  

---

## Estimated Time: 30 minutes
