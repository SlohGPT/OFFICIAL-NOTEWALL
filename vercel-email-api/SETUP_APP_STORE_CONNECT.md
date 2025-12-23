# NoteWall App Store Connect API Setup Guide

## Step 1: Get App Store Connect API Credentials

### 1.1 Generate API Key

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Users and Access** (top menu)
3. Click **Keys** tab (under "App Store Connect API")
4. Click the **+** button to generate a new key (or select existing)
5. Give it a name: "NoteWall Analytics API"
6. Select **Access**: Choose "Admin" or "App Manager" role
7. Click **Generate**
8. **Download the `.p8` file immediately** (you can only download it once!)

### 1.2 Copy These Values:

After generating the key, you'll see:

- **Issuer ID**: `57246542-96fe-1a63-e053-0824d011072a` (example)
  - Find it at the top of the Keys page
  
- **Key ID**: `2X9R4HXF34` (example)
  - Next to your key name in the keys list

- **Private Key**: Contents of the `.p8` file you downloaded
  - Open the file in a text editor
  - Copy everything including the `-----BEGIN PRIVATE KEY-----` headers

### 1.3 Get Your App ID

1. In App Store Connect, go to **My Apps**
2. Click on **NoteWall**
3. Go to **App Information** (left sidebar)
4. Find **Apple ID** (it's a number like `1234567890`)
5. Copy this number

## Step 2: Configure Vercel Environment Variables

1. Go to your Vercel dashboard: https://vercel.com/dashboard
2. Select your project (notewall-email-api or whatever it's called)
3. Go to **Settings** → **Environment Variables**
4. Add these variables:

```
ASC_ISSUER_ID = <paste Issuer ID>
ASC_KEY_ID = <paste Key ID>  
ASC_PRIVATE_KEY = <paste entire .p8 file contents including headers>
ASC_APP_ID = <paste Apple ID number>
ASC_BASE_DOWNLOAD_COUNT = 80
CRON_SECRET = <generate a random string like: openssl rand -base64 32>
```

**Important for ASC_PRIVATE_KEY:**
- Include the full key with headers
- Example format:
```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQg...
(multiple lines)
...your actual key content...
-----END PRIVATE KEY-----
```

## Step 3: Enable Vercel KV (for caching)

1. In Vercel dashboard, go to **Storage** tab
2. Click **Create Database** → **KV** (Key-Value)
3. Give it a name: "notewall-cache"
4. Click **Create**
5. Go to the KV database settings
6. Click **Connect to your project**
7. Select your API project and click **Connect**

Vercel will automatically add these environment variables:
- `KV_URL`
- `KV_REST_API_URL`
- `KV_REST_API_TOKEN`
- `KV_REST_API_READ_ONLY_TOKEN`

## Step 4: Deploy to Vercel

In your terminal:

```bash
cd vercel-email-api
npm install
vercel deploy --prod
```

## Step 5: Update Your iOS App Config

In your Swift app, update the Config:

```swift
// In UserCountService.swift or Config extension
static let userCountAPIURL: String? = "https://your-vercel-app.vercel.app/api/user-count"
```

Replace `your-vercel-app` with your actual Vercel deployment URL.

## Step 6: Test It

1. Visit: `https://your-vercel-app.vercel.app/api/user-count`
2. You should see JSON like:
```json
{
  "count": 80,
  "lastUpdated": "2024-12-22T10:30:00.000Z",
  "cached": false
}
```

## Troubleshooting

### Error: Missing environment variables
- Check all environment variables are set in Vercel
- Redeploy after adding variables

### Error: Invalid JWT token
- Make sure `ASC_PRIVATE_KEY` includes the full key with headers
- Check there are no extra quotes or escape characters
- Try wrapping the key in single quotes in Vercel UI

### Count not updating
- Check Vercel Logs: Dashboard → Deployments → View Function Logs
- Verify the cron job is running: Dashboard → Crons
- Manually trigger update: `https://your-app.vercel.app/api/cron/update-user-count?auth=<CRON_SECRET>`

## Notes

- The count updates automatically every hour via cron job
- First API call may take longer (cold start)
- Cache prevents hitting App Store Connect API rate limits
- Fallback to cached value if API fails

## Advanced: Get Real Download Analytics

The current implementation uses `ASC_BASE_DOWNLOAD_COUNT` because the App Store Connect API doesn't directly expose total downloads in app metadata.

To get real download numbers, you need to:

1. Enable **Analytics Reports API** access (requires special permissions)
2. Parse **Sales and Trends reports** (daily CSV downloads)
3. Or use a third-party service like **AppFigures** or **Sensor Tower**

For most cases, manually updating `ASC_BASE_DOWNLOAD_COUNT` weekly from App Store Connect dashboard is the simplest approach.
