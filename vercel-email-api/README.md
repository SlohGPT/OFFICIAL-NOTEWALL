# NoteWall Email API - Quick Deploy

This sends feedback emails automatically in the background (users never see email composer).

## 🚀 Deploy in 3 Steps

### Step 1: Install Vercel CLI

```bash
npm i -g vercel
```

### Step 2: Deploy

```bash
cd vercel-email-api
vercel
```

Follow the prompts. It will give you a URL like: `https://your-project.vercel.app`

### Step 3: Set Environment Variables

1. Go to: https://vercel.com/dashboard
2. Select your project
3. Go to **Settings → Environment Variables**
4. Add:
   - `GMAIL_USER`: `iosnotewall@gmail.com` (your email)
   - `GMAIL_APP_PASSWORD`: Your Gmail App Password (see below)

### Get Gmail App Password:

1. Go to: https://myaccount.google.com/security
2. Enable **2-Step Verification** (if not already)
3. Go to **"App passwords"**
4. Create new → Select "Mail" → Select "Other" → Name it "NoteWall"
5. Copy the 16-character password
6. Paste into Vercel environment variable

### Step 4: Update Your App

In `FeedbackService.swift`, line 19:

```swift
var emailWebhookURL: String? = "https://your-project.vercel.app/api/send-feedback"
```

Replace `your-project` with your actual Vercel project name.

## ✅ Done!

Now feedback emails are sent automatically - users never see anything!

## 🧪 Test

```bash
curl -X POST https://your-project.vercel.app/api/send-feedback \
  -H "Content-Type: application/json" \
  -d '{
    "to": "iosnotewall@gmail.com",
    "subject": "Test",
    "body": "Test email from NoteWall"
  }'
```

Check your email inbox!

