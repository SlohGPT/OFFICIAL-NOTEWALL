# Get Your Vendor Number - Required for Real Download Data

## What is the Vendor Number?

The Vendor Number is a 9-digit identifier that gives access to your app's sales reports from Apple. This is the ONLY way to get real download counts automatically.

## How to Find It:

### Method 1: App Store Connect Website

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **Payments and Financial Reports** (or **Sales and Trends**)
3. Look at the top of the page - your Vendor Number is displayed
4. It's a 9-digit number (e.g., `123456789`)

### Method 2: Sales and Trends Section

1. In App Store Connect, go to **Sales and Trends**
2. Click **Reports** tab
3. At the top, you'll see your Vendor Number

### Method 3: If You Can't Find It

If you don't see Payments/Sales sections:
- You need the **Admin** or **Finance** role in App Store Connect
- Contact your account admin to get access or have them provide the number

## What to Do With It:

Once you have your Vendor Number:

1. **Add to Vercel Environment Variables:**
   ```
   ASC_VENDOR_NUMBER = your-9-digit-number
   ```

2. **Redeploy:**
   ```bash
   vercel deploy --prod
   ```

3. **Done!** The system will now fetch REAL download counts from Apple's sales reports automatically.

## What Happens:

**Without Vendor Number:**
- System uses estimated growth (base count + 3 downloads/day)
- Still works, but not 100% accurate

**With Vendor Number:**
- System fetches actual daily sales reports from Apple
- Parses real download numbers
- Updates automatically every hour
- Shows TRUE download count in your app

## Troubleshooting:

**"I don't have access to Payments/Financial"**
→ Ask your App Store Connect account admin

**"My app is free, do I need this?"**
→ YES! Sales reports include free downloads too

**"Can I use a different method?"**
→ No, Apple doesn't provide total download counts any other way via API

---

**Bottom line:** Get your Vendor Number → Add it to Vercel → Get 100% real download counts automatically! 🎯
