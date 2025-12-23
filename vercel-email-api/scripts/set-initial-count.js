/**
 * Manual Update Script - Set Initial Download Count
 * 
 * Run this ONCE to set your current download count from App Store Connect
 * After this, the system will auto-increment based on estimated daily growth
 * 
 * Usage: node scripts/set-initial-count.js 80
 */

import { kv } from '@vercel/kv';

const initialCount = parseInt(process.argv[2]) || 80;

console.log(`\n🔧 Setting initial download count to: ${initialCount}\n`);

try {
  await kv.set('notewall_last_known_count', initialCount);
  await kv.set('notewall_last_count_update', Date.now());
  
  console.log('✅ Initial count set successfully!');
  console.log('   Count:', initialCount);
  console.log('   Date:', new Date().toISOString());
  console.log('\n📈 From now on, the count will auto-increment by ~3 downloads per day');
  console.log('   You can verify at: https://your-project.vercel.app/api/user-count\n');
  
  process.exit(0);
} catch (error) {
  console.error('❌ Error:', error.message);
  console.log('\n💡 Make sure you have:');
  console.log('   1. Deployed to Vercel');
  console.log('   2. Created and connected Vercel KV database');
  console.log('   3. Set KV environment variables\n');
  process.exit(1);
}
