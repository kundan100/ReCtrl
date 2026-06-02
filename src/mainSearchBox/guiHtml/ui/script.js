// ReCtrl Search - JavaScript Logic (IE-compatible)

var searchInput = null;

// Initialize when page loads
window.onload = function() {
    searchInput = document.getElementById('searchInput');
    
    // Handle search input changes (IE-compatible)
    // if (searchInput.attachEvent) {
    //     searchInput.attachEvent('oninput', handleSearchChange);
    //     searchInput.attachEvent('onkeydown', handleKeyPress);
    // } else {
    //     searchInput.addEventListener('input', handleSearchChange);
    //     searchInput.addEventListener('keydown', handleKeyPress);
    // }
    
    // Focus on load
    // searchInput.focus();
    if (searchInput) {
        searchInput.focus();
    }
};

// Handle search text changes
function handleSearchChange(e) {
    // e = e || window.event;
    // var target = e.target || e.srcElement;
    // var searchText = target.value;
    
    // // Send to AHK (WebView2 communication)
    // if (window.chrome && window.chrome.webview) {
    //     window.chrome.webview.postMessage({
    //         type: 'searchChange',
    //         value: searchText
    //     });
    // }
}

// Handle key presses
function handleKeyPress(e) {
    // e = e || window.event;
    // var keyCode = e.keyCode || e.which;
    // var key = e.key;
    
    // // Enter key (keyCode 13)
    // if (keyCode === 13 || key === 'Enter') {
    //     var searchText = searchInput.value;
        
    //     // Send to AHK
    //     if (window.chrome && window.chrome.webview) {
    //         window.chrome.webview.postMessage({
    //             type: 'searchSubmit',
    //             value: searchText
    //         });
    //     }
    // } 
    // // Escape key (keyCode 27)
    // else if (keyCode === 27 || key === 'Escape') {
    //     closeWindow();
    // }
}

// Close window
function closeWindow() {
    // if (window.chrome && window.chrome.webview) {
    //     window.chrome.webview.postMessage({
    //         type: 'closeWindow'
    //     });
    // }
}

// Clear search field (called from AHK)
function clearSearch() {
    if (searchInput) {
        searchInput.value = '';
    }
}
