// background.js

const TARGET_URL = 'https://www.amazon.com.br/gp/cart/view.html';
const OFFSCREEN_PATH = 'offscreen.html';

// 1. Setup Alarms
// 1. Setup Alarms
chrome.runtime.onInstalled.addListener(async () => {
  console.log('Extension installed/updated.');

  // Ensure alarm exists
  chrome.alarms.get('checkPrices', (alarm) => {
    if (!alarm) {
      chrome.alarms.create('checkPrices', { periodInMinutes: 1440 });
    }
  });

  // Check storage to avoid overwriting existing data
  const data = await chrome.storage.local.get(['prices', 'config']);

  const updates = {};
  if (!data.config) {
    updates.config = {
      interval: 1440,
      method: 'percentage',
      value: 10
    };
  }
  if (!data.prices) {
    updates.prices = {};
  }

  if (Object.keys(updates).length > 0) {
    console.log('Initializing default storage:', updates);
    await chrome.storage.local.set(updates);
  }
});

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === 'checkPrices') {
    console.log('Alarm fired: checkPrices');
    await checkPrices();
  }
});

// Listener to update alarm when settings change
chrome.storage.onChanged.addListener((changes, area) => {
  // Update alarm only if interval changed significantly or method changed
  if (area === 'local' && changes.config) {
    const newConfig = changes.config.newValue;
    if (newConfig.interval) {
      chrome.alarms.get('checkPrices', (alarm) => {
        if (!alarm || alarm.periodInMinutes !== newConfig.interval) {
          chrome.alarms.create('checkPrices', { periodInMinutes: parseFloat(newConfig.interval) });
        }
      });
    }
  }
});

// Listen for manual check from popup or analyze request
// Listen for manual check from popup
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'CHECK_NOW') {
    checkPrices().then(() => {
      sendResponse({ success: true });
    }).catch((err) => {
      console.error('Manual check error:', err);
      sendResponse({ success: false, error: err.toString() });
    });
    return true; // Async response
  }
});




// 2. Main Logic
async function checkPrices() {
  try {
    // Cache Busting: Appending timestamp prevents cached stale responses
    const t = Date.now();
    const response = await fetch(`${TARGET_URL}?t=${t}`, { cache: "no-store" });

    if (!response.ok) {
      throw new Error(`Failed to fetch cart: ${response.status}`);
    }
    if (response.redirected && response.url.includes('signin')) {
      throw new Error('User not logged in (Redirected to Sign-in)');
    }
    const htmlText = await response.text();
    console.log(`Fetched Cart HTML: ${htmlText.length} chars. Preview: ${htmlText.substring(0, 100)}...`);

    const items = await parseHtmlInOffscreen(htmlText);
    if (!items) throw new Error('Parsing returned no items (undefined response)');

    console.log('Parsed items:', items);
    await processItems(items);
    return { success: true, count: items.length };

  } catch (error) {
    console.error('Error in checkPrices:', error);
    throw error; // Re-throw so the caller knows it failed
  }
}

async function processItems(currentItems) {
  const data = await chrome.storage.local.get(['prices', 'config']);
  let storedPrices = data.prices || {};
  const config = data.config || { method: 'percentage', value: 10 };

  // Full Sync: We rebuild the storage map based ONLY on current items.
  // This effectively deletes items that were removed from Amazon.
  const nextStoredPrices = {};
  let dropDetected = false;

  for (const item of currentItems) {
    const { id, title, price } = item;

    // Retrieve existing data to preserve history
    const oldItemData = storedPrices[id];

    let history = [];
    if (oldItemData && Array.isArray(oldItemData.history)) {
      history = oldItemData.history;
    } else {
      // Migration for very old format or new item
      if (oldItemData && oldItemData.price) {
        history.push({
          date: new Date(oldItemData.lastUpdated || Date.now()).toISOString(),
          price: oldItemData.price
        });
      }
    }

    // [NEW] Sanitize (keep only valid prices)
    history = history.filter(h => h.price > 10);
    const lastEntry = history.length > 0 ? history[history.length - 1] : null;

    // [NEW] Anomaly Detection
    if (lastEntry) {
      const oldPrice = lastEntry.price;
      const increase = (price - oldPrice) / oldPrice * 100;
      if (increase > 200) {
        console.warn(`Anomaly for ${id}: +${increase.toFixed(0)}%. Resetting history.`);
        history = [];
      }
    }

    // Notification Logic
    // Re-check lastEntry safe
    const lastEntrySafe = history.length > 0 ? history[history.length - 1] : null;
    if (lastEntrySafe && lastEntrySafe.price > 10) {
      const oldPrice = lastEntrySafe.price;
      const priceDiff = oldPrice - price;

      let notify = false;
      if (config.method === 'percentage') {
        if ((priceDiff / oldPrice) * 100 >= config.value) notify = true;
      } else {
        if (priceDiff >= config.value) notify = true;
      }

      if (notify && priceDiff > 0) {
        dropDetected = true;
        sendNotification(title, oldPrice, price);
      }
    }

    // Add new entry
    const newEntry = {
      date: new Date().toISOString(),
      price: price
    };

    const lastEntryDate = lastEntry ? new Date(lastEntry.date).toDateString() : null;
    const currentDate = new Date().toDateString();

    if (!lastEntry || lastEntry.price !== price || lastEntryDate !== currentDate) {
      history.push(newEntry);
    }

    // Limit history
    if (history.length > 30) history.shift();

    // Add to new map
    nextStoredPrices[id] = {
      title: title,
      history: history
    };
  }

  // Overwrite storage with the new synced map
  console.log(`Sync complete. Storing ${Object.keys(nextStoredPrices).length} items (was ${Object.keys(storedPrices).length}).`);
  await chrome.storage.local.set({ prices: nextStoredPrices });
}





function sendNotification(title, oldPrice, newPrice) {
  const msg = `Price Drop! ${title.substring(0, 30)}... went from R$ ${oldPrice.toFixed(2)} to R$ ${newPrice.toFixed(2)}`;
  chrome.notifications.create({
    type: 'basic',
    iconUrl: 'icon.png',
    title: 'Amazon Price Alert',
    message: msg,
    priority: 2
  });
}

// 3. Offscreen Document Handling
async function parseHtmlInOffscreen(html) {
  await setupOffscreenDocument(OFFSCREEN_PATH);

  return new Promise((resolve, reject) => {
    chrome.runtime.sendMessage({
      target: 'offscreen',
      type: 'PARSE',
      html: html
    }, (response) => {
      if (chrome.runtime.lastError) {
        reject(new Error('Offscreen message failed: ' + chrome.runtime.lastError.message));
      } else {
        resolve(response);
      }
    });
  });
}

async function setupOffscreenDocument(path) {
  // Check for existing offscreen document
  // Compatible with older Chrome versions by using clients.matchAll if runtime.getContexts missing
  if (globalThis.chrome && chrome.runtime && chrome.runtime.getContexts) {
    const contexts = await chrome.runtime.getContexts({
      contextTypes: ['OFFSCREEN_DOCUMENT'],
      documentUrls: [chrome.runtime.getURL(path)]
    });
    if (contexts.length > 0) return;
  } else {
    // Fallback or explicit check via clients
    const matched = await clients.matchAll({ includeUncontrolled: true, type: 'window' });
    for (const c of matched) {
      if (c.url.endsWith(path)) return;
    }
  }

  // Attempt to create
  try {
    await chrome.offscreen.createDocument({
      url: path,
      reasons: [chrome.offscreen.Reason.DOM_PARSER],
      justification: 'Parse Amazon Cart HTML',
    });
  } catch (err) {
    if (err.message.startsWith('Only a single offscreen')) {
      // It exists, ignore
      return;
    }
    throw err;
  }
}
