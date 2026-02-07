// js/offscreen.js

// Listen for messages from the service worker
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.target === 'offscreen') {
        if (message.type === 'PARSE') {
            const items = parseCart(message.html);
            sendResponse(items);
        }
        return true;
    }
});



function parseCart(htmlString) {
    const parser = new DOMParser();
    const doc = parser.parseFromString(htmlString, 'text/html');

    // Debug: Check if we are on a login page or empty cart
    const title = doc.querySelector('title')?.textContent || '';
    if (title.includes('Sign In') || title.includes('Fazer login')) {
        console.error('Parser: Page title indicates login required:', title);
        return []; // Will result in 0 items
    }

    // Selectors strategies
    // 1. Active Cart
    // 2. Saved for Later (secondary cart)

    // Strategy A: Specific containers to avoid "Recommended" items
    const activeItems = Array.from(doc.querySelectorAll('#sc-active-cart .sc-list-item[data-asin]'));
    const savedItems = Array.from(doc.querySelectorAll('#sc-saved-cart .sc-list-item[data-asin], #sc-secondary-list .sc-list-item[data-asin]'));

    let itemElements = [...activeItems, ...savedItems];

    console.log(`Parser: Found ${activeItems.length} active and ${savedItems.length} saved items.`);

    // Strategy B: Fallback to generic if simplified view
    if (itemElements.length === 0) {
        itemElements = doc.querySelectorAll('.sc-list-item[data-asin]');
    }

    // Strategy C: Last resort
    if (itemElements.length === 0) {
        itemElements = doc.querySelectorAll('.sc-list-item');
    }

    console.log(`Parser: Found ${itemElements.length} candidate items.`);

    const results = [];

    itemElements.forEach(el => {
        const asin = el.getAttribute('data-asin');
        if (!asin) return;

        // Extract Title: Try multiple selectors
        let title = 'Unknown Product';
        const titleSelectors = [
            '.sc-product-title',
            '.a-truncate-full',
            '.sc-grid-item-product-title',
            'span.a-list-item a.a-link-normal span'
        ];

        for (const sel of titleSelectors) {
            const tEl = el.querySelector(sel);
            if (tEl) {
                title = tEl.textContent.trim();
                break;
            }
        }

        // Extract Price: Try multiple selectors
        // Added .a-offscreen as it's often the hidden reliable price
        let priceRaw = '';
        const priceSelectors = [
            '.sc-product-price',
            '.sc-price',
            '.a-offscreen', // [NEW] crucial for many Amazon views
            '.a-color-price',
            'span[id^="sc-subtotal-amount-buybox"]'
        ];

        // Specific exclusion terms
        const invalidTerms = ['economize', 'save', 'poupe', 'desconto', 'de:', 'was:', 'recomendado'];

        for (const sel of priceSelectors) {
            const candidates = el.querySelectorAll(sel);
            for (const pEl of candidates) {
                // [NEW] Ignore strikethrough prices (list price)
                if (pEl.classList.contains('a-text-strike') || pEl.closest('.a-text-strike')) continue;

                const text = pEl.textContent.trim();
                const textLower = text.toLowerCase();

                // Check if the price element itself contains invalid terms
                if (invalidTerms.some(term => textLower.includes(term))) continue;

                // Check immediate parent context
                if (pEl.parentElement) {
                    const parentText = pEl.parentElement.textContent.toLowerCase();
                    // Heuristic: If the parent text is short and contains invalid terms, skip.
                    if (parentText.length < 50 && invalidTerms.some(term => parentText.includes(term))) continue;
                }

                // If it passes, use it
                // Prioritize if it looks like a valid currency
                if (/R\$\s?[\d.,]+/.test(text)) {
                    priceRaw = text;
                    break;
                }
            }
            if (priceRaw) break;
        }

        // Deep fallback: the price might be text inside a div if it's a grid view
        if (!priceRaw) {
            const text = el.innerText || '';
            const matches = [...text.matchAll(/R\$\s?[\d.,]+/g)];
            for (const m of matches) {
                const valStr = m[0];
                const index = m.index;
                const prefix = text.substring(Math.max(0, index - 20), index).toLowerCase();

                if (invalidTerms.some(term => prefix.includes(term))) continue;

                // Extra check: is this line crossed out? (Hard to tell from innerText, rely on selectors ideally)

                priceRaw = valStr;
                break;
            }
        }

        if (priceRaw) {
            const priceVal = parseCurrency(priceRaw);
            // [NEW] Ignore low values (accessories/errors) <= 10.00
            if (priceVal !== null && priceVal > 10) {
                results.push({
                    id: asin,
                    title: title,
                    price: priceVal
                });
            } else if (priceVal !== null) {
                console.log(`Parser: Ignored low price (<= 4) for ASIN ${asin}: ${priceVal}`);
            } else {
                console.log(`Parser: Failed to parse currency from "${priceRaw}" for ASIN ${asin}`);
            }
        } else {
            console.warn(`Parser: No price found for ASIN ${asin} (${title}). HTML snippet:`, el.outerHTML.substring(0, 500));
        }
    });

    return results;
}

/**
 * Parses Brazilian currency strings into float.
 * Examples: 
 * "R$ 1.250,99" -> 1250.99
 * "R$ 1.250" -> 1250.00
 * "R$ 50,00" -> 50.00
 */
function parseCurrency(str) {
    // Remove "R$", spaces, and other non-number/non-punctuation chars
    // Keep digits, dots, and commas
    let clean = str.replace(/[^\d.,]/g, '').trim();

    if (!clean) return null;

    // European/Brazilian format: 
    // 1.000,00 -> 1000.00
    // 50,00 -> 50.00
    // 100 -> 100.00 (Unlikely but possible)

    // Check if it has a comma (decimal separator in BRL)
    if (clean.includes(',')) {
        // Remove all dots (thousand separators)
        clean = clean.replace(/\./g, '');
        // Replace comma with dot
        clean = clean.replace(',', '.');
    } else {
        // If no comma, does it have a dot? 
        // Could be just "100" or could be "1.000"
        // Usually, without cents, it might be an integer.
        // But if it looks like "1.000", is that 1000 or 1?
        // In BRL context, dots are thousands.
        // Use a heuristic: if we have ONE dot and 3 digits after, it's thousands.
        // Actually, just stripping dots is safest for BRL full amounts like "1.200"
        // But price usually has cents "1.200,00".

        // Let's assume standard BRL formatting always uses comma for decimal if cents exist.
        // If no comma, assume integer? Or malformed?
        // Let's try to be safe: remove dots.
        clean = clean.replace(/\./g, '');
    }

    const val = parseFloat(clean);
    return isNaN(val) ? null : val;
}
