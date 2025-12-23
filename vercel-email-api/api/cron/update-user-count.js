/**
 * Vercel Cron Job - Update User Count from App Store Connect
 * 
 * Runs every hour to fetch and cache the latest download count
 * 
 * Configuration in vercel.json:
 * {
 *   "crons": [{
 *     "path": "/api/cron/update-user-count",
 *     "schedule": "0 * * * *"
 *   }]
 * }
 */

import { kv } from '@vercel/kv';

export default async function handler(req, res) {
  // Verify this is a Vercel Cron request
  const authHeader = req.headers.authorization;
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    console.log('Cron job started: Updating user count...');
    
    const { generateToken } = await import('../utils/app-store-connect.js');
    const token = await generateToken();
    const appId = process.env.ASC_APP_ID;
    
    // Fetch app metadata
    const url = `https://api.appstoreconnect.apple.com/v1/apps/${appId}`;
    const response = await fetch(url, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (!response.ok) {
      throw new Error(`App Store Connect API error: ${response.status}`);
    }
    
    // For now, use base count from environment
    // TODO: Parse actual download count when Analytics API is configured
    const baseCount = parseInt(process.env.ASC_BASE_DOWNLOAD_COUNT || '80');
    
    // Update cache
    await kv.set('notewall_download_count', baseCount);
    await kv.set('notewall_download_count_timestamp', Date.now());
    
    console.log('Cron job completed: Count updated to', baseCount);
    
    res.status(200).json({ 
      success: true, 
      count: baseCount,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('Cron job error:', error);
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
}
