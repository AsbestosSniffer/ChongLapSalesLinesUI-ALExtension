(function () {
    var root = document.getElementById('controlAddIn');

    root.innerHTML =
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

    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ControlAddInReady', []);
}());
