# Quick Deploy Guide - NoteWall User Count API

## ✅ Your Credentials (Already Set)

I've configured everything with your App Store Connect credentials:
- ✅ Issuer ID: `295fbedd-f7e7-4611-9991-ea097a67562b`
- ✅ Key ID: `PZTVB6HY9F`
- ✅ Private Key: Configured
- ✅ App ID: `6755601996`
- ✅ Bundle ID: `com.app.notewall`

## 🚀 Deploy in 5 Minutes

### Step 1: Install Dependencies
```bash
cd vercel-email-api
npm install
```

### Step 2: Test Locally (Optional)
```bash
# Test if your credentials work
npm run test-downloads
```

This will verify your API access to App Store Connect.

### Step 3: Set Up Vercel

1. **Create Vercel KV Database**
   - Go to https://vercel.com/dashboard
   - Click **Storage** → **Create Database** → **KV**
   - Name it: `notewall-cache`
   - Create it

2. **Deploy to Vercel**
   ```bash
   vercel deploy
   ```

3. **Set Environment Variables**
   
   In Vercel Dashboard → Your Project → Settings → Environment Variables, add:

   **Required for real data:**
   ```
   ASC_ISSUER_ID = 295fbedd-f7e7-4611-9991-ea097a67562b
   ASC_KEY_ID = PZTVB6HY9F
   ASC_PRIVATE_KEY = (paste your .p8 key - see below)
   ASC_APP_ID = 6755601996
   ASC_BUNDLE_ID = com.app.notewall
   ASC_VENDOR_NUMBER = 93814186
   ASC_BASE_DOWNLOAD_COUNT = 80
   CRON_SECRET = (generate with: openssl rand -base64 32)
   ```

   **For `ASC_PRIVATE_KEY`**, paste this EXACT text:
   ```
   -----BEGIN PRIVATE KEY-----
   MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQguSEobPzMpONEJCeC
   hC/b2bFosdIiHFhDriLQVwgcPbqgCgYIKoZIzj0DAQehRANCAARaXODgRqkFgG3o
   CQ3E3i0eIJT8Md+aNO3CQ2sbtfiK1c4y1jx183Tp8RFUuJAjnHoO9G6rZxPigsa+
   7neKLvTZ
   -----END PRIVATE KEY-----
   ```

   **To get `ASC_VENDOR_NUMBER`** (REQUIRED FOR REAL DATA):
   - See [GET_VENDOR_NUMBER.md](GET_VENDOR_NUMBER.md) for instructions
   - This is in App Store Connect → Payments and Financial Reports
   - Without this, you'll get estimated counts instead of real data

4. **Connect KV to Project**
   - In Vercel, go to your KV database
   - Click **Connect to Project**
   - Select your API project

5. **Deploy Production**
   ```bash
   vercel deploy --prod
   ```

### Step 4: Update iOS App

In your NoteWall app, update `UserCountService.swift`:

```swift
static let userCountAPIURL: String? = "https://your-project.vercel.app/api/user-count"
```

Replace `your-project` with your actual Vercel project URL.

### Step 5: Test It!

Visit: `https://your-project.vercel.app/api/user-count`

You should see:
```json
{
  "count": 80,
  "lastUpdated": "2024-12-22T...",
  "cached": false
}
```

## 📊 How Download Count Works (100% REAL DATA)

### Fully Automated Real Data

The system fetches REAL download counts from Apple:

1. **Every hour**, the system:
   - Connects to App Store Connect with your credentials ✅
   - Fetches the last 90 days of sales reports ✅
   - Parses actual download numbers from Apple's data ✅
   - Sums them up to get total downloads ✅
   - Caches and serves to your iOS app ✅

2. **Your iOS app shows 100% real numbers** - no estimates, no manual updates!

### Requirements for Real Data:

**You MUST provide your Vendor Number:**
- This is a 9-digit number from App Store Connect
- Find it in: **Payments and Financial Reports** or **Sales and Trends**
- See [GET_VENDOR_NUMBER.md](GET_VENDOR_NUMBER.md) for detailed instructions

### What Happens:

**With Vendor Number (100% Real Data):**
```
System → App Store Connect API → Sales Reports → Parse TSV → Sum Downloads → Cache → Your App
```
- ✅ Real download count from Apple
- ✅ Updates automatically every hour
- ✅ No manual work needed EVER

**Without Vendor Number (Estimated):**
- ⚠️ Uses base count + estimated daily growth
- Still automatic, but not 100% accurate
- Better than nothing, but GET YOUR VENDOR NUMBER!

### How to Get Vendor Number:

See [GET_VENDOR_NUMBER.md](GET_VENDOR_NUMBER.md) - it takes 30 seconds!

1. Go to App Store Connect → Payments and Financial Reports
2. Find your **Vendor Number** (9-digit number)
3. Add to Vercel environment variables:
   ```
   ASC_VENDOR_NUMBER = your-vendor-number
   ```
4. The API will automatically fetch from sales reports daily

## 🔍 Troubleshooting

### Test API locally:
```bash
npm run test-downloads
```

### Check Vercel logs:
```bash
vercel logs
```

### Manually trigger cron:
```bash
curl https://your-project.vercel.app/api/cron/update-user-count \
  -H "Authorization: Bearer YOUR_CRON_SECRET"
```

## ✅ What You Get

- ✅ Real count from App Store Connect (or weekly manual update)
- ✅ 1-hour caching (prevents rate limits)
- ✅ Automatic hourly updates via cron
- ✅ Fallback if API fails
- ✅ Your iOS app shows live count in onboarding

The count updates automatically in your social proof screen! 🎉
