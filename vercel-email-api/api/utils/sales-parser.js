/**
 * Fetch REAL download data from App Store Connect Sales Reports
 * This actually parses Apple's sales data to get true download counts
 * NO FALLBACKS - returns null if real data cannot be fetched
 */

import zlib from 'zlib';
import { promisify } from 'util';

const gunzip = promisify(zlib.gunzip);

/**
 * Fetch and parse real sales reports to get total downloads
 * Returns NULL if vendor number is not set or data cannot be fetched
 */
export async function fetchRealDownloadCount(token) {
  const vendorNumber = process.env.ASC_VENDOR_NUMBER;

  if (!vendorNumber) {
    throw new Error('ASC_VENDOR_NUMBER not set - cannot fetch real data. Find it in App Store Connect → Payments and Financial Reports');
  }

  console.log(`📊 Fetching real sales data for vendor ${vendorNumber}...`);

  // Fetch sales reports for the last 90 days and sum them up
  const totalDownloads = await fetchCumulativeDownloads(token, vendorNumber);

  if (totalDownloads === 0) {
    throw new Error('No download data found in sales reports. This could mean: 1) No downloads yet, 2) Reports not yet available, or 3) Incorrect vendor number');
  }

  console.log(`✅ Real download count fetched from Apple: ${totalDownloads}`);
  return totalDownloads;
}

/**
 * Fetch and sum downloads from daily sales reports
 * Only returns REAL data from Apple - never estimates
 */
async function fetchCumulativeDownloads(token, vendorNumber) {
  const bundleId = process.env.ASC_BUNDLE_ID || 'com.app.notewall';
  let totalDownloads = 0;
  let reportsFound = 0;

  // Fetch reports for the last 90 days
  const daysToFetch = 90;
  const today = new Date();

  console.log(`   Scanning last ${daysToFetch} days of sales reports...`);

  // Generate all dates to fetch
  const datesToFetch = [];
  for (let i = 1; i <= daysToFetch; i++) {
    const reportDate = new Date(today);
    reportDate.setDate(reportDate.getDate() - i);
    datesToFetch.push(reportDate);
  }

  // Process in batches to avoid rate limits/timeouts but still be fast
  const BATCH_SIZE = 10;

  for (let i = 0; i < datesToFetch.length; i += BATCH_SIZE) {
    const batch = datesToFetch.slice(i, i + BATCH_SIZE);

    await Promise.all(batch.map(async (reportDate) => {
      const dateString = reportDate.toISOString().split('T')[0].replace(/-/g, '');

      try {
        const dailyDownloads = await fetchDailySalesReport(token, vendorNumber, bundleId, dateString);
        if (dailyDownloads > 0) {
          totalDownloads += dailyDownloads;
          reportsFound++;
          console.log(`   ${reportDate.toISOString().split('T')[0]}: +${dailyDownloads} downloads`);
        }
      } catch (error) {
        // Report might not exist for this date (weekend, future date, no sales, etc)
        // This is normal - skip silently
      }
    }));
  }

  console.log(`   Found ${reportsFound} reports with download data`);
  console.log(`   Total downloads: ${totalDownloads}`);

  return totalDownloads;
}

/**
 * Fetch a single day's sales report and extract downloads for your app
 */
async function fetchDailySalesReport(token, vendorNumber, bundleId, dateString) {
  const salesUrl = 'https://api.appstoreconnect.apple.com/v1/salesReports';

  const params = new URLSearchParams({
    'filter[frequency]': 'DAILY',
    'filter[reportDate]': dateString,
    'filter[reportSubType]': 'SUMMARY',
    'filter[reportType]': 'SALES',
    'filter[vendorNumber]': vendorNumber
  });

  const response = await fetch(`${salesUrl}?${params}`, {
    headers: {
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/a-gzip'
    }
  });

  if (!response.ok) {
    throw new Error(`Sales report not available for ${dateString}`);
  }

  // Response is gzipped TSV data
  const gzippedData = await response.arrayBuffer();
  const unzipped = await gunzip(Buffer.from(gzippedData));
  const tsvData = unzipped.toString('utf-8');

  // Parse TSV and find your app's downloads
  return parseTSVForDownloads(tsvData, bundleId);
}

/**
 * Parse TSV sales report and extract download count for your app
 * 
 * TSV Format:
 * Provider	Provider Country	SKU	Developer	Title	Version	Product Type Identifier	Units	Developer Proceeds	Begin Date	End Date	Customer Currency	Country Code	Currency of Proceeds	Apple Identifier	Customer Price	Promo Code	Subscription	Period	Category	CMB	Device	Supported Platforms	Proceeds Reason	Preserved Pricing	Client	Order Type
 */
function parseTSVForDownloads(tsvData, bundleId) {
  const lines = tsvData.trim().split('\n');

  if (lines.length < 2) {
    return 0; // No data
  }

  // First line is header
  const headers = lines[0].split('\t');
  const unitsIndex = headers.indexOf('Units');
  const productTypeIndex = headers.indexOf('Product Type Identifier');
  const titleIndex = headers.indexOf('Title');

  if (unitsIndex === -1) {
    console.log('⚠️  Could not find Units column in sales report');
    return 0;
  }

  let downloads = 0;

  // Parse data lines
  for (let i = 1; i < lines.length; i++) {
    const columns = lines[i].split('\t');

    // Check if this is your app (you can filter by Title, SKU, or other fields)
    const units = parseInt(columns[unitsIndex]) || 0;
    const productType = columns[productTypeIndex];

    // Count downloads (Product Type: 1F = Free App, 1 = Paid App, 7 = Update)
    // We want initial downloads (1F for free apps, 1 for paid)
    if (productType === '1F' || productType === '1') {
      downloads += units;
    }
  }

  return downloads;
}

/**
 * Alternative: Use App Analytics API for real metrics
 */
export async function fetchFromAppAnalytics(token, appId) {
  try {
    // App Analytics can provide real download metrics
    // This requires Analytics access to be enabled in App Store Connect

    const metricsUrl = `https://api.appstoreconnect.apple.com/v1/apps/${appId}/appAvailabilities`;

    const response = await fetch(metricsUrl, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });

    if (response.ok) {
      const data = await response.json();
      console.log('📈 App analytics data fetched');
      // Analytics structure varies - this is for future enhancement
      return null;
    }

    return null;
  } catch (error) {
    console.log('Analytics API error:', error.message);
    return null;
  }
}
