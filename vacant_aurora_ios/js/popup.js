// js/popup.js

document.addEventListener('DOMContentLoaded', init);

// Cache DOM
const listView = document.getElementById('listView');
const detailView = document.getElementById('detailView');
const itemList = document.getElementById('itemList');
const checkNowBtn = document.getElementById('checkNowBtn');
const backBtn = document.getElementById('backBtn');
const statusMsg = document.getElementById('status');

// Details elements
const detailTitle = document.getElementById('detailTitle');
const detailCurrent = document.getElementById('detailCurrent');
const detailLowest = document.getElementById('detailLowest');
const detailHighest = document.getElementById('detailHighest');
const canvas = document.getElementById('priceChart');
const ctx = canvas.getContext('2d');

const tabBtns = document.querySelectorAll('.tab-btn');
const tabContents = document.querySelectorAll('.tab-content');



function init() {
    loadItems();
    checkNowBtn.addEventListener('click', handleCheckNow);
    backBtn.addEventListener('click', showList);
}



function showList() {
    detailView.classList.add('hidden');
    listView.classList.remove('hidden');
    loadItems(); // Refresh data
}

function showDetails(item) {
    listView.classList.add('hidden');
    detailView.classList.remove('hidden');

    // Render Stats
    detailTitle.textContent = item.title;

    // Get stats from history
    const history = (item.history || []).filter(h => h.price > 10);
    if (history.length === 0) {
        // Fallback if empty (shouldn't happen if item exists)
        detailCurrent.textContent = '-';
        return;
    }

    const prices = history.map(h => h.price);
    const current = prices[prices.length - 1];
    const min = Math.min(...prices);
    const max = Math.max(...prices);

    detailCurrent.textContent = `R$ ${current.toFixed(2)}`;
    detailLowest.textContent = `R$ ${min.toFixed(2)}`;
    detailHighest.textContent = `R$ ${max.toFixed(2)}`;

    // Draw Graph
    drawChart(history);
}

function loadItems() {
    chrome.storage.local.get(['prices'], (result) => {
        itemList.innerHTML = '';
        if (!result.prices || Object.keys(result.prices).length === 0) {
            itemList.innerHTML = '<p class="status-msg">No items tracked yet.</p>';
            return;
        }

        const ul = document.createElement('div');
        const sortedItems = Object.entries(result.prices).sort(([, a], [, b]) => {
            const getPercentageChange = (item) => {
                const cleanHistory = (item.history || []).filter(h => h.price > 10);
                if (cleanHistory.length < 2) return 0;
                const current = cleanHistory[cleanHistory.length - 1].price;
                const first = cleanHistory[0].price; // Baseline: First collected price
                return (current - first) / first * 100;
            };
            return getPercentageChange(a) - getPercentageChange(b);
        });

        for (const [id, item] of sortedItems) {
            // Get last price info
            let priceDisplay = 'N/A';
            let dateDisplay = '';

            // Filter history for display
            const cleanHistory = (item.history || []).filter(h => h.price > 8);

            // Handle both old format (migrating) and new format
            if (cleanHistory.length > 0) {
                const last = cleanHistory[cleanHistory.length - 1];
                priceDisplay = `R$ ${last.price.toFixed(2)}`;
                dateDisplay = new Date(last.date).toLocaleDateString();
            } else if (item.price) {
                // Old format fallback
                priceDisplay = `${item.price.toFixed(2)}`;
            }

            const div = document.createElement('div');
            div.className = 'product-item';

            // Helper to check if item is book (duplicated from background for UI logic)
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


            // Trend Signal Logic
            let trendHtml = '';
            let trendClass = 'sig-yellow'; // Default stable
            let trendTitle = 'Price stable';
            let percentageDisplay = '';

            if (cleanHistory.length >= 2) {
                const current = cleanHistory[cleanHistory.length - 1].price;
                const first = cleanHistory[0].price; // Baseline: First collected price
                const change = (current - first) / first * 100;

                if (Math.abs(change) > 0.01) {
                    percentageDisplay = `<span style="font-size: 0.85em; margin-left: 4px; color: ${change < 0 ? '#4caf50' : '#f44336'};">(${change > 0 ? '+' : ''}${change.toFixed(1)}%)</span>`;
                }

                if (current < first) {
                    trendClass = 'sig-green';
                    trendTitle = 'Price dropped since start!';
                } else if (current > first) {
                    trendClass = 'sig-red';
                    trendTitle = 'Price increased since start';
                }
            }
            trendHtml = `<span class="signal-dot ${trendClass}" title="${trendTitle}"></span>${percentageDisplay}`;

            div.innerHTML = `
                <div style="flex: 1; padding-right: 10px;">
                    <span class="p-title">${truncate(item.title, 35)}</span>
                    <span class="p-date">Amazon: R$ ${priceDisplay} ${trendHtml}</span>
                </div>

            `;

            // Make the whole row clickable for details, but prevent link click from triggering it if using <a>
            div.addEventListener('click', (e) => {
                if (e.target.tagName !== 'A') {
                    showDetails(item);
                }
            });
            ul.appendChild(div);
        }
        itemList.appendChild(ul);
    });
}

function handleCheckNow() {
    checkNowBtn.disabled = true;
    checkNowBtn.textContent = '...';
    statusMsg.textContent = 'Checking prices...';

    chrome.runtime.sendMessage({ type: 'CHECK_NOW' }, (response) => {
        checkNowBtn.disabled = false;
        checkNowBtn.textContent = '↻ Check Now';

        if (response && response.success) {
            statusMsg.textContent = 'Updated!';
            setTimeout(() => statusMsg.textContent = '', 2000);
            loadItems();
        } else {
            statusMsg.textContent = 'Failed. See console.';
            statusMsg.style.color = 'red';
        }
    });
}

function truncate(str, n) {
    return (str.length > n) ? str.substr(0, n - 1) + '...' : str;
}

// --- Canvas Charting Logic ---

function drawChart(history) {
    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    if (history.length < 2) {
        ctx.font = '12px Arial';
        ctx.fillStyle = '#666';
        ctx.fillText('Not enough data for graph', 80, 100);
        return;
    }

    const padding = 30;
    const chartWidth = canvas.width - padding * 2;
    const chartHeight = canvas.height - padding * 2;

    // 1. Calculate Scales
    const prices = history.map(h => h.price);
    const minPrice = Math.min(...prices) * 0.95; // 5% buffer bottom
    const maxPrice = Math.max(...prices) * 1.05; // 5% buffer top
    const priceRange = maxPrice - minPrice;

    // Time scale (equidistant for simplicity, or actually time based?)
    // If daily, equidistant is fine.
    const stepX = chartWidth / (history.length - 1);

    // 2. Helper to map values
    const getY = (price) => {
        // Higher price = lower Y (0 is top)
        const rel = (price - minPrice) / priceRange;
        return (padding + chartHeight) - (rel * chartHeight);
    };

    const getX = (index) => padding + (index * stepX);

    // 3. Draw Grid/Axes
    ctx.beginPath();
    ctx.strokeStyle = '#eee';
    ctx.moveTo(padding, padding);
    ctx.lineTo(padding, canvas.height - padding); // Y axis
    ctx.lineTo(canvas.width - padding, canvas.height - padding); // X axis
    ctx.stroke();

    // 4. Draw Line
    ctx.beginPath();
    ctx.strokeStyle = '#ff9900'; // Amazon Orange
    ctx.lineWidth = 2;

    history.forEach((h, i) => {
        const x = getX(i);
        const y = getY(h.price);
        if (i === 0) ctx.moveTo(x, y);
        else ctx.lineTo(x, y);
    });
    ctx.stroke();

    // 5. Draw Points
    ctx.fillStyle = '#232f3e'; // Amazon Blue
    history.forEach((h, i) => {
        const x = getX(i);
        const y = getY(h.price);
        ctx.beginPath();
        ctx.arc(x, y, 3, 0, Math.PI * 2);
        ctx.fill();
    });

    // 6. Labels (Min/Max Y)
    ctx.fillStyle = '#666';
    ctx.font = '10px Arial';
    ctx.fillText(maxPrice.toFixed(0), 5, padding);
    ctx.fillText(minPrice.toFixed(0), 5, canvas.height - padding);
}
