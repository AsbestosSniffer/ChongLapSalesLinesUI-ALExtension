var ipcCallback = null;
var ipcCart = {};
var ipcSearchTimer = null;

function ItemPickerCart(element, callback) {
    ipcCallback = callback;

    element.innerHTML =
        '<div class="ipc-container">' +
        '  <div class="ipc-search-panel">' +
        '    <div class="ipc-search-box">' +
        '      <input type="text" id="ipc-search-input" placeholder="Search items by number or description..." autocomplete="off" />' +
        '    </div>' +
        '    <div id="ipc-results" class="ipc-results"></div>' +
        '  </div>' +
        '  <div class="ipc-cart-panel">' +
        '    <div class="ipc-cart-header">Cart</div>' +
        '    <div id="ipc-cart-items" class="ipc-cart-items"></div>' +
        '    <div class="ipc-cart-footer">' +
        '      <button id="ipc-cancel-btn" class="ipc-btn ipc-btn-secondary" type="button">Cancel</button>' +
        '      <button id="ipc-add-btn" class="ipc-btn ipc-btn-primary" type="button">Add to Sales Lines</button>' +
        '    </div>' +
        '  </div>' +
        '</div>';

    document.getElementById('ipc-search-input').addEventListener('input', ipcOnSearchInput);
    document.getElementById('ipc-cancel-btn').addEventListener('click', ipcOnCancel);
    document.getElementById('ipc-add-btn').addEventListener('click', ipcOnAddToSalesLines);

    ipcRenderCart();
    ipcSetResultsMessage('Loading items...');

    callback('ControlAddInReady');
}

function ipcOnSearchInput(e) {
    var value = e.target.value;
    if (ipcSearchTimer) {
        clearTimeout(ipcSearchTimer);
    }
    ipcSetResultsMessage('Searching...');
    ipcSearchTimer = setTimeout(function () {
        ipcCallback('RequestSearch', value);
    }, 300);
}

// Called from AL with a JSON array of items: [{no, description, unitPrice, uom, picture}, ...]
function LoadItems(itemsJson) {
    var items = [];
    try {
        items = JSON.parse(itemsJson);
    } catch (ex) {
        items = [];
    }
    ipcRenderResults(items);
}

// Called from AL to show a message to the user
function ShowMessage(message) {
    alert(message);
}

function ipcSetResultsMessage(message) {
    var container = document.getElementById('ipc-results');
    container.innerHTML = '<div class="ipc-empty">' + ipcEscapeHtml(message) + '</div>';
}

function ipcRenderResults(items) {
    var container = document.getElementById('ipc-results');
    container.innerHTML = '';

    if (!items || items.length === 0) {
        container.innerHTML = '<div class="ipc-empty">No items found</div>';
        return;
    }

    items.forEach(function (item) {
        var card = document.createElement('div');
        card.className = 'ipc-item-card';

        var img = document.createElement('div');
        img.className = 'ipc-item-img';
        if (item.picture) {
            img.style.backgroundImage = "url('" + item.picture + "')";
        } else {
            img.classList.add('ipc-no-image');
            img.textContent = 'No Image';
        }

        var info = document.createElement('div');
        info.className = 'ipc-item-info';
        info.innerHTML =
            '<div class="ipc-item-no">' + ipcEscapeHtml(item.no) + '</div>' +
            '<div class="ipc-item-desc">' + ipcEscapeHtml(item.description) + '</div>' +
            '<div class="ipc-item-price">' + ipcFormatNumber(item.unitPrice) + ' / ' + ipcEscapeHtml(item.uom) + '</div>';

        card.appendChild(img);
        card.appendChild(info);

        card.addEventListener('click', function () {
            ipcAddToCart(item);
        });

        container.appendChild(card);
    });
}

function ipcAddToCart(item) {
    if (ipcCart[item.no]) {
        ipcCart[item.no].quantity += 1;
    } else {
        ipcCart[item.no] = {
            no: item.no,
            description: item.description,
            unitPrice: item.unitPrice,
            uom: item.uom,
            picture: item.picture,
            quantity: 1
        };
    }
    ipcRenderCart();
}

function ipcRenderCart() {
    var container = document.getElementById('ipc-cart-items');
    container.innerHTML = '';

    var keys = Object.keys(ipcCart);
    if (keys.length === 0) {
        container.innerHTML = '<div class="ipc-empty">Cart is empty.<br/>Click an item on the left to add it.</div>';
        return;
    }

    keys.forEach(function (no) {
        var entry = ipcCart[no];

        var row = document.createElement('div');
        row.className = 'ipc-cart-row';

        var img = document.createElement('div');
        img.className = 'ipc-cart-img';
        if (entry.picture) {
            img.style.backgroundImage = "url('" + entry.picture + "')";
        } else {
            img.classList.add('ipc-no-image');
        }

        var info = document.createElement('div');
        info.className = 'ipc-cart-info';
        info.innerHTML =
            '<div class="ipc-item-no">' + ipcEscapeHtml(entry.no) + '</div>' +
            '<div class="ipc-item-desc">' + ipcEscapeHtml(entry.description) + '</div>';

        var qtyControls = document.createElement('div');
        qtyControls.className = 'ipc-qty-controls';

        var decBtn = document.createElement('button');
        decBtn.type = 'button';
        decBtn.className = 'ipc-qty-btn';
        decBtn.textContent = '-';
        decBtn.addEventListener('click', function () { ipcChangeQty(no, -1); });

        var qtyInput = document.createElement('input');
        qtyInput.type = 'number';
        qtyInput.className = 'ipc-qty-input';
        qtyInput.min = '0';
        qtyInput.step = 'any';
        qtyInput.value = entry.quantity;
        qtyInput.addEventListener('change', function () { ipcSetQty(no, parseFloat(qtyInput.value)); });

        var incBtn = document.createElement('button');
        incBtn.type = 'button';
        incBtn.className = 'ipc-qty-btn';
        incBtn.textContent = '+';
        incBtn.addEventListener('click', function () { ipcChangeQty(no, 1); });

        qtyControls.appendChild(decBtn);
        qtyControls.appendChild(qtyInput);
        qtyControls.appendChild(incBtn);

        var removeBtn = document.createElement('button');
        removeBtn.type = 'button';
        removeBtn.className = 'ipc-remove-btn';
        removeBtn.title = 'Remove';
        removeBtn.innerHTML = '&times;';
        removeBtn.addEventListener('click', function () { ipcRemoveFromCart(no); });

        row.appendChild(img);
        row.appendChild(info);
        row.appendChild(qtyControls);
        row.appendChild(removeBtn);

        container.appendChild(row);
    });
}

function ipcChangeQty(no, delta) {
    if (!ipcCart[no]) {
        return;
    }
    var newQty = ipcRound(ipcCart[no].quantity + delta);
    if (newQty <= 0) {
        delete ipcCart[no];
    } else {
        ipcCart[no].quantity = newQty;
    }
    ipcRenderCart();
}

function ipcSetQty(no, value) {
    if (!ipcCart[no]) {
        return;
    }
    if (isNaN(value) || value <= 0) {
        delete ipcCart[no];
    } else {
        ipcCart[no].quantity = value;
    }
    ipcRenderCart();
}

function ipcRemoveFromCart(no) {
    delete ipcCart[no];
    ipcRenderCart();
}

function ipcOnCancel() {
    ipcCallback('RequestClose');
}

function ipcOnAddToSalesLines() {
    var lines = Object.keys(ipcCart).map(function (no) {
        return { no: ipcCart[no].no, quantity: ipcCart[no].quantity };
    });

    if (lines.length === 0) {
        ipcCallback('RequestClose');
        return;
    }

    ipcCallback('AddLines', JSON.stringify(lines));
}

function ipcEscapeHtml(text) {
    if (text === undefined || text === null) {
        return '';
    }
    var div = document.createElement('div');
    div.textContent = String(text);
    return div.innerHTML;
}

function ipcFormatNumber(value) {
    if (value === undefined || value === null || value === '') {
        return '';
    }
    return Number(value).toFixed(2);
}

function ipcRound(value) {
    return Math.round(value * 100000) / 100000;
}
