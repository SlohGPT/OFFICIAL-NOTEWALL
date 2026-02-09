# Deployment Instructions for Resend Email API

## What Changed
- **Replaced:** nodemailer → Resend API
- **API Key:** `re_SMhC7U6f_Lew2A9Ku5w3VuMxZDtyx3u3i`
- **Benefit:** More reliable email delivery

## Quick Deploy to Vercel

### 1. Install Dependencies
```bash
cd vercel-email-api
npm install
```

### 2. Set Environment Variable in Vercel
Go to your Vercel project dashboard:
1. Navigate to **Settings** → **Environment Variables**
2. Add this variable:
   - **Name:** `RESEND_API_KEY`
   - **Value:** `re_SMhC7U6f_Lew2A9Ku5w3VuMxZDtyx3u3i`
   - **Environment:** Production, Preview, Development (all)

### 3. Deploy
```bash
npm run deploy
# or just
vercel
```

### 4. Test
After deployment, test the endpoint:
```bash
curl -X POST https://vercel-email-api-rho.vercel.app/api/send-feedback \
  -H "Content-Type: application/json" \
  -d '{
    "to": "iosnotewall@gmail.com",
    "subject": "Test Feedback",
    "body": "This is a test from the new Resend integration!",
    "reason": "Testing",
    "details": "Just checking if emails work",
    "isPremium": false
  }'
```

You should receive an email at `iosnotewall@gmail.com` within seconds!

## Important Notes
- The Resend free tier allows 100 emails/day, 3,000 emails/month
- Emails will come from `NoteWall Feedback <onboarding@resend.dev>`
- To use a custom domain (e.g., `feedback@notewall.com`), you need to:
  1. Upgrade to Resend Pro ($20/month)
  2. Add and verify your domain in Resend dashboard

## Troubleshooting
If emails aren't working:
1. Check Vercel logs: `vercel logs`
2. Verify environment variable is set in Vercel dashboard
3. Check Resend dashboard for delivery logs: https://resend.com/emails
