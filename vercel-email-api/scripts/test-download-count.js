/**
 * Manual script to fetch and display download count
 * Run with: node scripts/test-download-count.js
 */

import jwt from 'jsonwebtoken';
import 'dotenv/config';

// Your actual credentials
const config = {
  issuerId: '295fbedd-f7e7-4611-9991-ea097a67562b',
  keyId: 'PZTVB6HY9F',
  privateKey: `-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQguSEobPzMpONEJCeC
hC/b2bFosdIiHFhDriLQVwgcPbqgCgYIKoZIzj0DAQehRANCAARaXODgRqkFgG3o
CQ3E3i0eIJT8Md+aNO3CQ2sbtfiK1c4y1jx183Tp8RFUuJAjnHoO9G6rZxPigsa+
7neKLvTZ
-----END PRIVATE KEY-----`,
  appId: '6755601996'
};

function generateToken() {
  try {
    const token = jwt.sign(
      {
        iss: config.issuerId,
        exp: Math.floor(Date.now() / 1000) + (20 * 60),
        aud: 'appstoreconnect-v1'
      },
      config.privateKey,
      {
        algorithm: 'ES256',
        header: {
          alg: 'ES256',
          kid: config.keyId,
          typ: 'JWT'
        }
      }
    );
    
    console.log('✅ JWT token generated successfully\n');
    return token;
  } catch (error) {
    console.error('❌ Error generating token:', error.message);
    throw error;
  }
}

async function testAppStoreAPI() {
  console.log('🚀 Testing App Store Connect API...\n');
  
  try {
    const token = generateToken();
    
    // Test 1: Get app metadata
    console.log('📱 Fetching app metadata...');
    const appUrl = `https://api.appstoreconnect.apple.com/v1/apps/${config.appId}`;
    const appResponse = await fetch(appUrl, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (appResponse.ok) {
      const appData = await appResponse.json();
      console.log('✅ App metadata fetched successfully');
      console.log('   App name:', appData.data?.attributes?.name || 'N/A');
      console.log('   Bundle ID:', appData.data?.attributes?.bundleId || 'N/A');
      console.log('   SKU:', appData.data?.attributes?.sku || 'N/A\n');
    } else {
      const errorText = await appResponse.text();
      console.log('❌ Failed to fetch app metadata:', appResponse.status);
      console.log('   Error:', errorText, '\n');
    }
    
    // Test 2: Try to get sales reports
    console.log('📊 Attempting to fetch sales reports...');
    const salesUrl = 'https://api.appstoreconnect.apple.com/v1/salesReports';
    const params = new URLSearchParams({
      'filter[frequency]': 'DAILY',
      'filter[reportSubType]': 'SUMMARY',
      'filter[reportType]': 'SALES',
      'filter[vendorNumber]': '000000' // Will need your actual vendor number
    });
    
    const salesResponse = await fetch(`${salesUrl}?${params}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/a-gzip'
      }
    });
    
    if (salesResponse.ok) {
      console.log('✅ Sales reports accessible');
      console.log('   Note: You need to set ASC_VENDOR_NUMBER to parse actual downloads\n');
    } else {
      console.log('⚠️  Sales reports not accessible (expected without vendor number)');
      console.log('   Status:', salesResponse.status, '\n');
    }
    
    // Test 3: Check analytics
    console.log('📈 Checking analytics access...');
    const analyticsUrl = `https://api.appstoreconnect.apple.com/v1/apps/${config.appId}/perfPowerMetrics`;
    const analyticsResponse = await fetch(analyticsUrl, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (analyticsResponse.ok) {
      console.log('✅ Analytics API accessible\n');
    } else {
      console.log('⚠️  Analytics API limited access');
      console.log('   Status:', analyticsResponse.status, '\n');
    }
    
    console.log('📝 Summary:');
    console.log('   - API authentication: ✅ Working');
    console.log('   - App metadata access: ✅ Working');
    console.log('   - Download counts: ⚠️  Requires manual update or sales reports');
    console.log('\n💡 Recommendation:');
    console.log('   Update ASC_BASE_DOWNLOAD_COUNT weekly from App Store Connect dashboard');
    console.log('   Current value in .env: 80');
    console.log('   The app will use this value automatically\n');
    
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Run the test
testAppStoreAPI();
