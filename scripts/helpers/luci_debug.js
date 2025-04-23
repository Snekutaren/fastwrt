// LuCI debugging script
// To use: Open browser developer tools (F12) while in LuCI interface
// Paste this entire script into the console and press Enter
// Then try to create a new wireless network and observe the console output

(function() {
    console.log("LuCI Wireless Form Debugging Script Activated");
    
    // Monitor form submission events
    document.addEventListener('submit', function(e) {
        console.log("Form submission detected:", e);
        console.log("Form data:", new FormData(e.target));
    }, true);
    
    // Monitor button clicks
    document.addEventListener('click', function(e) {
        if (e.target.tagName === 'BUTTON' || 
            (e.target.tagName === 'INPUT' && e.target.type === 'submit')) {
            console.log("Button clicked:", e.target);
            console.log("Button properties:", {
                disabled: e.target.disabled,
                form: e.target.form,
                id: e.target.id,
                className: e.target.className
            });
        }
    }, true);
    
    // Monitor changes to form fields
    document.addEventListener('change', function(e) {
        if (e.target.tagName === 'SELECT' || e.target.tagName === 'INPUT') {
            console.log(`Form field "${e.target.name}" changed to "${e.target.value}"`);
        }
    }, true);
    
    // Monitor network dropdown specifically
    const monitorNetworkDropdown = () => {
        const networkSelects = document.querySelectorAll('select[name*="network"]');
        if (networkSelects.length > 0) {
            networkSelects.forEach(select => {
                console.log("Network dropdown found:", select);
                console.log("Available options:", Array.from(select.options).map(o => ({
                    value: o.value,
                    text: o.text,
                    selected: o.selected
                })));
                
                // Add special monitoring for this dropdown
                if (!select.dataset.monitored) {
                    select.dataset.monitored = "true";
                    select.addEventListener('change', function() {
                        console.log("Network changed to:", this.value);
                        // Check if save button is disabled after network selection
                        setTimeout(() => {
                            const saveButtons = document.querySelectorAll('button[type="submit"], input[type="submit"]');
                            saveButtons.forEach(btn => {
                                console.log(`Save button state after network selection: ${btn.disabled ? 'DISABLED' : 'ENABLED'}`);
                            });
                        }, 100);
                    });
                }
            });
        } else {
            console.log("No network dropdown found yet, will check again soon");
        }
    };
    
    // Check for validation error messages
    const checkForErrors = () => {
        const errorElements = document.querySelectorAll('.alert-message, .error, [data-error]');
        if (errorElements.length > 0) {
            console.log("Validation errors found:");
            errorElements.forEach(el => {
                console.log("Error:", el.textContent);
            });
        }
    };
    
    // Monitor AJAX requests
    const origOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function() {
        this.addEventListener('load', function() {
            console.log("XHR request completed:", {
                url: this._url,
                status: this.status,
                response: this.responseText.substring(0, 500) + (this.responseText.length > 500 ? '...' : '')
            });
        });
        this._url = arguments[1];
        origOpen.apply(this, arguments);
    };
    
    // Run monitoring functions periodically
    setInterval(() => {
        monitorNetworkDropdown();
        checkForErrors();
    }, 1000);
    
    console.log("Debugging hooks installed. Try to create a wireless network now.");
    console.log("When the save button becomes disabled or you can't save, check the console for errors.");
})();