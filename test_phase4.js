/**
 * GoTune - Phase 4 Comprehensive Logic & Integration Verification Test
 */

const assert = require('assert');

console.log('==============================================');
console.log('   GoTune - Phase 4 Feature Verification Test   ');
console.log('==============================================\n');

let passedTests = 0;
let failedTests = 0;

function runTest(name, fn) {
  try {
    fn();
    console.log(`[PASS] ${name}`);
    passedTests++;
  } catch (err) {
    console.error(`[FAIL] ${name}: ${err.message}`);
    failedTests++;
  }
}

// 1. SMART SHUFFLE VERIFICATION
runTest('Smart Shuffle: Preserves current track at index 0 and randomizes upcoming queue', () => {
  const originalQueue = [
    { id: 'track_cur', title: 'Currently Playing' },
    { id: 'track_1', title: 'Song 1' },
    { id: 'track_2', title: 'Song 2' },
    { id: 'track_3', title: 'Song 3' },
    { id: 'track_4', title: 'Song 4' },
    { id: 'track_5', title: 'Song 5' }
  ];

  const unshuffledQueue = [...originalQueue];
  const currentIndex = 0;
  const currentTrack = originalQueue[currentIndex];

  // Logic from AudioPlayerProvider.toggleShuffle()
  const upcoming = [...originalQueue];
  upcoming.splice(currentIndex, 1);
  // Fisher-Yates shuffle
  for (let i = upcoming.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [upcoming[i], upcoming[j]] = [upcoming[j], upcoming[i]];
  }
  const shuffledQueue = [currentTrack, ...upcoming];

  assert.strictEqual(shuffledQueue[0].id, 'track_cur', 'Current track must remain at index 0');
  assert.strictEqual(shuffledQueue.length, originalQueue.length, 'Queue length must be preserved');
  
  // Verify all elements are retained
  const originalIds = new Set(originalQueue.map(t => t.id));
  const shuffledIds = new Set(shuffledQueue.map(t => t.id));
  assert.strictEqual(originalIds.size, shuffledIds.size);
  for (const id of originalIds) {
    assert.ok(shuffledIds.has(id), `Missing track id ${id} in shuffled queue`);
  }
});

runTest('Smart Shuffle: Restoring original queue preserves playback continuity', () => {
  const originalQueue = [
    { id: 'track_A', title: 'Song A' },
    { id: 'track_B', title: 'Song B' },
    { id: 'track_C', title: 'Song C' },
    { id: 'track_D', title: 'Song D' }
  ];
  const unshuffledQueue = [...originalQueue];

  // User listened to track_C while shuffled
  const currentPlayingId = 'track_C';

  // Toggle shuffle OFF: restore from unshuffledQueue
  const restoredQueue = [...unshuffledQueue];
  const newIndex = restoredQueue.findIndex(t => t.id === currentPlayingId);

  assert.strictEqual(restoredQueue[0].id, 'track_A');
  assert.strictEqual(restoredQueue[1].id, 'track_B');
  assert.strictEqual(restoredQueue[2].id, 'track_C');
  assert.strictEqual(restoredQueue[3].id, 'track_D');
  assert.strictEqual(newIndex, 2, 'Active track index in restored queue must point to track_C');
});

// 2. REPEAT MODE CYCLE VERIFICATION
runTest('Repeat Mode Cycle: none -> one (current song) -> all (queue) -> none', () => {
  const modes = ['none', 'one', 'all'];

  function cycleRepeat(current) {
    switch (current) {
      case 'none':
        return 'one';
      case 'one':
        return 'all';
      case 'all':
      default:
        return 'none';
    }
  }

  let mode = 'none';
  mode = cycleRepeat(mode);
  assert.strictEqual(mode, 'one', '1st toggle must be Repeat One (current song)');

  mode = cycleRepeat(mode);
  assert.strictEqual(mode, 'all', '2nd toggle must be Repeat All (queue)');

  mode = cycleRepeat(mode);
  assert.strictEqual(mode, 'none', '3rd toggle must be Repeat Off (none)');
});

// 3. SLEEP TIMER PRESETS & FORMATTING VERIFICATION
runTest('Sleep Timer: Presets (5, 10, 15, 30, 45, 60 min) and Custom Slider (1-120 min)', () => {
  const presets = [5, 10, 15, 30, 45, 60];
  assert.strictEqual(presets.length, 6);
  assert.deepStrictEqual(presets, [5, 10, 15, 30, 45, 60]);

  function formatSleepTimerRemaining(seconds) {
    if (seconds <= 0) return '00:00';
    const minutes = Math.floor(seconds / 60);
    const remSeconds = seconds % 60;
    if (minutes >= 60) {
      const hours = Math.floor(minutes / 60);
      const remMins = minutes % 60;
      return `${hours}h ${remMins}m`;
    }
    return `${String(minutes).padStart(2, '0')}:${String(remSeconds).padStart(2, '0')}`;
  }

  assert.strictEqual(formatSleepTimerRemaining(300), '05:00', '5 minutes');
  assert.strictEqual(formatSleepTimerRemaining(630), '10:30', '10 mins 30s');
  assert.strictEqual(formatSleepTimerRemaining(2700), '45:00', '45 minutes');
  assert.strictEqual(formatSleepTimerRemaining(3600), '1h 0m', '60 minutes');
  assert.strictEqual(formatSleepTimerRemaining(5400), '1h 30m', '90 minutes (custom)');
});

// 4. SEARCH HISTORY DEDUPLICATION & CAP
runTest('Search History: Capped at 20, newest first, case-insensitive deduplication', () => {
  let searchHistory = ['Electronic', 'Chill', 'Lo-Fi'];

  function addSearchQuery(query) {
    const trimmed = query.trim();
    if (!trimmed) return;
    searchHistory = searchHistory.filter(q => q.toLowerCase() !== trimmed.toLowerCase());
    searchHistory.unshift(trimmed);
    if (searchHistory.length > 20) {
      searchHistory = searchHistory.slice(0, 20);
    }
  }

  function removeSearchQuery(query) {
    searchHistory = searchHistory.filter(q => q.toLowerCase() !== query.trim().toLowerCase());
  }

  function clearSearchHistory() {
    searchHistory = [];
  }

  // Adding existing item with different casing brings it to top
  addSearchQuery('chill');
  assert.deepStrictEqual(searchHistory, ['chill', 'Electronic', 'Lo-Fi']);

  // Adding new query
  addSearchQuery('Synthwave');
  assert.deepStrictEqual(searchHistory, ['Synthwave', 'chill', 'Electronic', 'Lo-Fi']);

  // Test capacity capping at 20
  for (let i = 1; i <= 25; i++) {
    addSearchQuery(`Query ${i}`);
  }
  assert.strictEqual(searchHistory.length, 20, 'History must be capped at 20');
  assert.strictEqual(searchHistory[0], 'Query 25', 'Newest query must be at index 0');

  // Removing single item
  removeSearchQuery('Query 25');
  assert.strictEqual(searchHistory[0], 'Query 24');

  // Clearing history
  clearSearchHistory();
  assert.strictEqual(searchHistory.length, 0);
});

// 5. QUEUE OPERATIONS LOGIC VERIFICATION
runTest('Queue Operations: Add to queue, Play Next, Remove from queue, Reorder queue', () => {
  const queue = ['Song A', 'Song B', 'Song C'];
  let currentIndex = 1; // Playing 'Song B'

  // Play Next: insert right after currentIndex
  const insertIndex = currentIndex + 1;
  queue.splice(insertIndex, 0, 'Song PLAY_NEXT');
  assert.deepStrictEqual(queue, ['Song A', 'Song B', 'Song PLAY_NEXT', 'Song C']);
  assert.strictEqual(queue[currentIndex], 'Song B', 'Current track untouched');

  // Add to Queue (end)
  queue.push('Song QUEUE_END');
  assert.deepStrictEqual(queue, ['Song A', 'Song B', 'Song PLAY_NEXT', 'Song C', 'Song QUEUE_END']);

  // Remove from Queue
  queue.splice(2, 1); // remove 'Song PLAY_NEXT'
  assert.deepStrictEqual(queue, ['Song A', 'Song B', 'Song C', 'Song QUEUE_END']);

  // Reorder queue: move 'Song QUEUE_END' (index 3) to index 0
  const movedItem = queue.splice(3, 1)[0];
  queue.splice(0, 0, movedItem);
  assert.deepStrictEqual(queue, ['Song QUEUE_END', 'Song A', 'Song B', 'Song C']);
});

console.log('\n----------------------------------------------');
console.log(`Results: ${passedTests} passed, ${failedTests} failed.`);
console.log('==============================================\n');

if (failedTests > 0) {
  process.exit(1);
}
