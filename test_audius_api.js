/**
 * GoTune - Audius API Integration Verification Script
 * Validates official live Audius API endpoints used by GoTune.
 */

const BASE_URL = 'https://api.audius.co/v1';
const APP_NAME = 'GoTune';

async function runTests() {
  console.log('==============================================');
  console.log('  GoTune - Audius API Live Integration Tests  ');
  console.log('==============================================\n');

  let passed = 0;
  let failed = 0;

  // Test 1: Audius Discovery Host Ping
  try {
    process.stdout.write('[TEST 1] Audius Discovery Node Ping... ');
    const res = await fetch('https://api.audius.co');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!data.data || !Array.isArray(data.data)) throw new Error('Missing discovery host data');
    console.log(`PASSED (Active host: ${data.data[0]})`);
    passed++;
  } catch (err) {
    console.log(`FAILED: ${err.message}`);
    failed++;
  }

  // Test 2: Trending Tracks Fetch
  let sampleTrackId = null;
  try {
    process.stdout.write('[TEST 2] Trending Tracks (/v1/tracks/trending)... ');
    const res = await fetch(`${BASE_URL}/tracks/trending?app_name=${APP_NAME}&limit=5`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!Array.isArray(data.data) || data.data.length === 0) {
      throw new Error('Empty trending list returned');
    }
    sampleTrackId = data.data[0].id;
    const firstTrack = data.data[0];
    console.log(`PASSED (${data.data.length} tracks fetched, First: "${firstTrack.title}" by ${firstTrack.user?.name})`);
    passed++;
  } catch (err) {
    console.log(`FAILED: ${err.message}`);
    failed++;
  }

  // Test 3: Search Tracks with Query
  try {
    process.stdout.write('[TEST 3] Search Tracks (/v1/tracks/search?query=summer)... ');
    const res = await fetch(`${BASE_URL}/tracks/search?query=summer&app_name=${APP_NAME}&limit=3`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (!Array.isArray(data.data)) throw new Error('Search did not return an array');
    console.log(`PASSED (${data.data.length} results returned, Top result: "${data.data[0]?.title}")`);
    passed++;
  } catch (err) {
    console.log(`FAILED: ${err.message}`);
    failed++;
  }

  // Test 4: Track Metadata by ID
  if (sampleTrackId) {
    try {
      process.stdout.write(`[TEST 4] Track Metadata (/v1/tracks/${sampleTrackId})... `);
      const res = await fetch(`${BASE_URL}/tracks/${sampleTrackId}?app_name=${APP_NAME}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      if (!data.data || !data.data.title) throw new Error('Invalid track metadata payload');
      console.log(`PASSED (Title: "${data.data.title}", Duration: ${data.data.duration}s, Genre: "${data.data.genre}")`);
      passed++;
    } catch (err) {
      console.log(`FAILED: ${err.message}`);
      failed++;
    }
  }

  // Test 5: Stream Resolution Endpoint
  if (sampleTrackId) {
    try {
      process.stdout.write(`[TEST 5] Stream URL Resolution (/v1/tracks/${sampleTrackId}/stream)... `);
      const res = await fetch(`${BASE_URL}/tracks/${sampleTrackId}/stream?app_name=${APP_NAME}`, {
        redirect: 'manual',
      });
      // Audius stream endpoint redirects with 302 to CDN / IPFS storage gateway
      if (res.status === 302) {
        const streamLocation = res.headers.get('location');
        console.log(`PASSED (HTTP 302 Redirect to stream URL)`);
        passed++;
      } else if (res.ok) {
        console.log(`PASSED (HTTP ${res.status} direct audio payload)`);
        passed++;
      } else {
        throw new Error(`Unexpected status ${res.status}`);
      }
    } catch (err) {
      console.log(`FAILED: ${err.message}`);
      failed++;
    }
  }

  // Test 6: Error Handling (Invalid Track ID)
  try {
    process.stdout.write('[TEST 6] Error Handling on Invalid ID (/v1/tracks/invalid_test_id)... ');
    const res = await fetch(`${BASE_URL}/tracks/invalid_test_id?app_name=${APP_NAME}`);
    if (res.status === 400 || res.status === 404) {
      console.log(`PASSED (Graceful HTTP ${res.status} error handling)`);
      passed++;
    } else {
      throw new Error(`Expected 400/404 but got ${res.status}`);
    }
  } catch (err) {
    console.log(`FAILED: ${err.message}`);
    failed++;
  }

  console.log('\n----------------------------------------------');
  console.log(`Results: ${passed} passed, ${failed} failed.`);
  console.log('==============================================\n');
}

runTests();
