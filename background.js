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

  // Set default Gemini Key key if not present (placeholder)
  if (!data.gemini_key) {
    updates.gemini_key = ''; // User must provide
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
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'CHECK_NOW') {
    checkPrices().then(() => {
      sendResponse({ success: true });
    }).catch((err) => {
      console.error('Manual check error:', err);
      sendResponse({ success: false, error: err.toString() });
    });
    return true; // Async response
  } else if (message.type === 'ANALYZE_CART') {
    analyzeCartBooks().then(report => {
      sendResponse({ success: true, report: report });
    }).catch(err => {
      console.error('Analyze error:', err);
      sendResponse({ success: false, error: err.toString() });
    });
    return true;
  }
});

// --- AI Librarian / Books Analysis --- //

// --- AI Librarian / Books Analysis (Google Gemini) --- //

async function analyzeCartBooks() {
  // 1. Get current items & API Key
  const data = await chrome.storage.local.get(['prices', 'gemini_key']);
  const items = Object.values(data.prices || {});
  const apiKey = data.gemini_key;

  if (!apiKey) return { error: "Google Gemini API Key is missing. Please check settings." };
  if (items.length === 0) return { error: "Cart is empty." };

  // 2. Filter for books
  const bookTitles = items
    .filter(item => isBook(item.title))
    .map(item => cleanTitle(item.title));

  if (bookTitles.length === 0) return { error: "No books identified in cart." };

  // 3. Call Gemini
  return await analyzeWithGemini(bookTitles, apiKey);
}

const GEMINI_SYSTEM_PROMPT = `
# Objective
Analyze a provided book wishlist, identify reading preferences, sequence the list for optimal reading, and suggest recommendations, handling unrecognized titles clearly.

Begin with a concise checklist (3-7 bullets) of what you will do; keep items conceptual, not implementation-level.

# Instructions
- Analyze the wishlist to identify:
  - Predominant genres
  - Recurring themes
  - Narrative styles (e.g., pace, intensity, introspection, commercial vs. literary)
  - Writing style and complexity
- Summarize and describe the user's reader profile based on the analysis.
- Organize the wishlist books into an optimal reading order, explaining each step (e.g., rationale for placement: emotional flow, complexity, thematic continuity, etc.).
- Suggest additional book recommendations, categorized by:
  - Highly aligned with the user's preferences
  - Similar to wishlist titles
  - Gentle expansions of the user's horizons (but not too far afield)
- Before any significant tool call or lookup, state in one line the purpose of the call and the minimal inputs used.
- After each major section or step, validate your analysis or sequencing in 1-2 lines and decide whether to proceed or adjust.
- Present all findings clearly, avoid spoilers, and structure the output as specified below.
- For any wishlist entries that are ambiguous, missing, or unrecognized, list them separately and include a brief description of the problem.

# Output Format
Return a JSON with the following structure:

\`\`\`json
{
  "pattern_analysis": {
    "genres": [string],
    "themes": [string],
    "narrative_style": [string],
    "writing_style_complexity": [string]
  },
  "reader_profile": string,
  "reading_order": [
    {
      "title": string,
      "explanation": string
    }
  ],
  "recommendations": {
    "highly_aligned": [string],
    "similar": [string],
    "expand_horizons": [string]
  },
  "unrecognized_entries": [
    {
      "entry": string,
      "issue": string
    }
  ]
}
\`\`\`

# Verbosity
- Be concise and well-structured. Explanations should be brief and spoiler-free.
`;

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'CHECK_NOW') {
    checkPrices().then(res => sendResponse(res));
    return true;
  } else if (message.type === 'ANALYZE_CART') {
    analyzeCartBooks().then(report => {
      sendResponse({ success: true, report: report });
    }).catch(err => {
      console.error('Analyze error:', err);
      sendResponse({ success: false, error: err.toString() });
    });
    return true;
  } else if (message.type === 'GET_PROMPT') {
    generatePromptText().then(text => {
      sendResponse({ success: true, prompt: text });
    });
    return true;
  }
});

async function generatePromptText() {
  const data = await chrome.storage.local.get(['prices']);
  const items = Object.values(data.prices || {});

  // Include ALL items, let the user/LLM filter. 
  // This solves "missing items" if our isBook filter was too strict.
  const titles = items.map(item => cleanTitle(item.title));

  if (titles.length === 0) return "No items found to analyze.";

  return GEMINI_SYSTEM_PROMPT + "\n\nMy Book Wishlist:\n" + titles.map(t => `- ${t}`).join('\n');
}

async function analyzeWithGemini(bookList, apiKey) {
  const userMessage = `My Book Wishlist:\n${bookList.map(t => `- ${t}`).join('\n')}`;

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`;

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contents: [{
          parts: [{ text: GEMINI_SYSTEM_PROMPT + "\n\n" + userMessage }]
        }],
        generationConfig: {
          response_mime_type: "application/json"
        }
      })
    });

    if (!response.ok) {
      const err = await response.json();
      throw new Error(err.error?.message || 'Unknown Gemini error');
    }

    const data = await response.json();
    const content = data.candidates[0].content.parts[0].text;
    return JSON.parse(content);

  } catch (error) {
    console.error('Gemini Analysis Error:', error);
    return { error: `Analysis failed: ${error.message}` };
  }
}


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



function isBook(title) {
  const lower = title.toLowerCase();
  const keywords = [
    'livro', 'book', 'capa comum', 'capa dura', 'capa',
    'edição', 'edicao', 'vol.', 'box', 'série', 'coleção',
    'paperback', 'hardcover', 'editora', 'autor',
    'brochura', 'encadernado', 'pocket', 'bolso',
    'kindle', 'ebook'
  ];
  return keywords.some(k => lower.includes(k));
}

function cleanTitle(title) {
  // Remove common clutter
  let clean = title;
  // Amazon specific terms
  clean = clean.replace(/\(Capa Comum\)/gi, '');
  clean = clean.replace(/\(Capa Dura\)/gi, '');
  clean = clean.replace(/Edição Português/gi, '');
  clean = clean.replace(/Amazon Exclusive/gi, '');
  clean = clean.replace(/[\[\(].*?[\]\)]/g, ''); // Remove content in brackets/parentheses often containing noise
  return clean.trim();
}

// Helper to reuse offscreen
async function parseInOffscreen(html, type) {
  await setupOffscreenDocument(OFFSCREEN_PATH);
  return new Promise((resolve) => {
    chrome.runtime.sendMessage({
      target: 'offscreen',
      type: type,
      html: html
    }, (response) => {
      resolve(response && response.price ? response.price : null);
    });
  });
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
