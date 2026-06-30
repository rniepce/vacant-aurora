// Parses the Amazon cart HTML and returns a JSON string of items.
// Shared verbatim with the iOS app's CartParser.parserScript — keep them in sync.
(function() {
    function parseCurrency(str) {
        let clean = str.replace(/[^\d.,]/g, '').trim();
        if (!clean) return null;
        if (clean.includes(',')) {
            clean = clean.replace(/\./g, '');
            clean = clean.replace(',', '.');
        } else {
            clean = clean.replace(/\./g, '');
        }
        const val = parseFloat(clean);
        return isNaN(val) ? null : val;
    }

    const title = document.querySelector('title')?.textContent || '';
    if (title.includes('Sign In') || title.includes('Fazer login') || title.includes('sign-in')) {
        return JSON.stringify({ error: 'login_required' });
    }

    const activeItems = Array.from(document.querySelectorAll('#sc-active-cart .sc-list-item[data-asin]'));
    const savedItems = Array.from(document.querySelectorAll('#sc-saved-cart .sc-list-item[data-asin], #sc-secondary-list .sc-list-item[data-asin]'));
    let itemElements = [...activeItems, ...savedItems];

    if (itemElements.length === 0) {
        itemElements = Array.from(document.querySelectorAll('.sc-list-item[data-asin]'));
    }
    if (itemElements.length === 0) {
        itemElements = Array.from(document.querySelectorAll('.sc-list-item'));
    }

    const results = [];
    const invalidTerms = ['economize', 'save', 'poupe', 'desconto', 'de:', 'was:', 'recomendado'];

    itemElements.forEach(el => {
        const asin = el.getAttribute('data-asin');
        if (!asin) return;

        let title = 'Unknown Product';
        const titleSelectors = ['.sc-product-title', '.a-truncate-full', '.sc-grid-item-product-title', 'span.a-list-item a.a-link-normal span'];
        for (const sel of titleSelectors) {
            const tEl = el.querySelector(sel);
            if (tEl) { title = tEl.textContent.trim(); break; }
        }

        // Extract product image URL
        let imageURL = '';
        const imgSelectors = ['.sc-product-image img', '.sc-item-image img', 'img[alt]', 'img'];
        for (const sel of imgSelectors) {
            const imgEl = el.querySelector(sel);
            if (imgEl && imgEl.src && !imgEl.src.includes('transparent-pixel') && !imgEl.src.includes('spacer')) {
                imageURL = imgEl.src;
                break;
            }
        }

        let priceRaw = '';
        const priceSelectors = ['.sc-product-price', '.sc-price', '.a-offscreen', '.a-color-price', 'span[id^="sc-subtotal-amount-buybox"]'];

        for (const sel of priceSelectors) {
            const candidates = el.querySelectorAll(sel);
            for (const pEl of candidates) {
                if (pEl.classList.contains('a-text-strike') || pEl.closest('.a-text-strike')) continue;
                const text = pEl.textContent.trim();
                const textLower = text.toLowerCase();
                if (invalidTerms.some(term => textLower.includes(term))) continue;
                if (pEl.parentElement) {
                    const parentText = pEl.parentElement.textContent.toLowerCase();
                    if (parentText.length < 50 && invalidTerms.some(term => parentText.includes(term))) continue;
                }
                if (/R\$\s?[\d.,]+/.test(text)) { priceRaw = text; break; }
            }
            if (priceRaw) break;
        }

        if (!priceRaw) {
            const text = el.innerText || '';
            const matches = [...text.matchAll(/R\$\s?[\d.,]+/g)];
            for (const m of matches) {
                const valStr = m[0];
                const index = m.index;
                const prefix = text.substring(Math.max(0, index - 20), index).toLowerCase();
                if (invalidTerms.some(term => prefix.includes(term))) continue;
                priceRaw = valStr;
                break;
            }
        }

        if (priceRaw) {
            const priceVal = parseCurrency(priceRaw);
            if (priceVal !== null && priceVal > 10) {
                results.push({ id: asin, title: title, price: priceVal, imageURL: imageURL || null });
            }
        }
    });

    return JSON.stringify({ items: results });
})();
