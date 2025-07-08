/**
 * FlowCraft Error Handler & Utilities
 * Universal error handling and utility functions for FlowCraft application
 */

class FlowCraftErrorHandler {
    constructor() {
        this.isOnline = navigator.onLine;
        this.retryAttempts = 3;
        this.retryDelay = 1000; // 1 second
        this.requestTimeout = 10000; // 10 seconds
        
        // Listen for online/offline events
        window.addEventListener('online', () => {
            this.isOnline = true;
            this.showNotification('Connection restored', 'success');
        });
        
        window.addEventListener('offline', () => {
            this.isOnline = false;
            this.showNotification('Connection lost. Working offline.', 'warning');
        });
    }

    /**
     * Enhanced Supabase request with error handling, timeout, and retry logic
     */
    async executeSupabaseRequest(requestFunction, options = {}) {
        const { 
            maxRetries = this.retryAttempts,
            timeout = this.requestTimeout,
            showLoading = true,
            loadingMessage = 'Processing...'
        } = options;

        if (!this.isOnline) {
            throw new Error('No internet connection. Please check your network and try again.');
        }

        let lastError;
        let loadingId;

        if (showLoading) {
            loadingId = this.showLoading(loadingMessage);
        }

        try {
            for (let attempt = 1; attempt <= maxRetries; attempt++) {
                try {
                    // Create timeout promise
                    const timeoutPromise = new Promise((_, reject) => {
                        setTimeout(() => reject(new Error('Request timeout')), timeout);
                    });

                    // Execute the request with timeout
                    const result = await Promise.race([
                        requestFunction(),
                        timeoutPromise
                    ]);

                    if (showLoading) {
                        this.hideLoading(loadingId);
                    }

                    // Check for Supabase errors
                    if (result.error) {
                        throw new Error(result.error.message || 'Database operation failed');
                    }

                    return result;

                } catch (error) {
                    lastError = error;
                    
                    if (attempt < maxRetries) {
                        // Wait before retry with exponential backoff
                        const delay = this.retryDelay * Math.pow(2, attempt - 1);
                        await this.sleep(delay);
                        
                        if (showLoading) {
                            this.updateLoadingMessage(loadingId, `Retrying... (${attempt}/${maxRetries})`);
                        }
                    }
                }
            }

            // All retries failed
            throw lastError;

        } catch (error) {
            if (showLoading) {
                this.hideLoading(loadingId);
            }
            throw this.handleError(error);
        }
    }

    /**
     * Centralized error handling
     */
    handleError(error) {
        console.error('FlowCraft Error:', error);
        
        let userMessage = 'An unexpected error occurred. Please try again.';
        let errorType = 'error';

        if (error.message) {
            // Network errors
            if (error.message.includes('fetch')) {
                userMessage = 'Connection error. Please check your internet connection.';
                errorType = 'warning';
            }
            // Timeout errors
            else if (error.message.includes('timeout')) {
                userMessage = 'Request timed out. Please try again.';
                errorType = 'warning';
            }
            // Supabase specific errors
            else if (error.message.includes('JWT')) {
                userMessage = 'Session expired. Please log in again.';
                errorType = 'warning';
                // Redirect to login after a short delay
                setTimeout(() => {
                    window.location.href = 'index.html';
                }, 2000);
            }
            // Database errors
            else if (error.message.includes('Database')) {
                userMessage = 'Database error. Please try again later.';
                errorType = 'error';
            }
            // Validation errors
            else if (error.message.includes('required') || error.message.includes('invalid')) {
                userMessage = error.message;
                errorType = 'validation';
            }
            // Generic error with message
            else {
                userMessage = error.message;
            }
        }

        this.showNotification(userMessage, errorType);
        return error;
    }

    /**
     * Input validation utilities
     */
    validateEmail(email) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!email || !email.trim()) {
            throw new Error('Email is required');
        }
        if (!emailRegex.test(email)) {
            throw new Error('Please enter a valid email address');
        }
        return true;
    }

    validatePassword(password) {
        if (!password || !password.trim()) {
            throw new Error('Password is required');
        }
        
        // Enhanced password policy
        const minLength = 12;
        const errors = [];
        
        if (password.length < minLength) {
            errors.push(`Password must be at least ${minLength} characters long`);
        }
        
        if (!/[a-z]/.test(password)) {
            errors.push('Password must contain at least one lowercase letter');
        }
        
        if (!/[A-Z]/.test(password)) {
            errors.push('Password must contain at least one uppercase letter');
        }
        
        if (!/[0-9]/.test(password)) {
            errors.push('Password must contain at least one number');
        }
        
        if (!/[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password)) {
            errors.push('Password must contain at least one special character');
        }
        
        // Check for common weak passwords
        const weakPasswords = [
            'password', 'flowcraft', '123456', 'qwerty', 'admin', 'user',
            'password123', 'admin123', 'flowcraft123', 'test123'
        ];
        
        if (weakPasswords.includes(password.toLowerCase())) {
            errors.push('Password is too common. Please choose a stronger password');
        }
        
        // Check for sequential characters
        if (/(?:abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz|123|234|345|456|567|678|789)/i.test(password)) {
            errors.push('Password should not contain sequential characters');
        }
        
        // Check for repeated characters
        if (/(.)\1{2,}/.test(password)) {
            errors.push('Password should not contain repeated characters');
        }
        
        if (errors.length > 0) {
            throw new Error(errors.join('. '));
        }
        
        return true;
    }

    validateProcessData(data) {
        if (!data.short_name || !data.short_name.trim()) {
            throw new Error('Process name is required');
        }
        if (data.short_name.length > 50) {
            throw new Error('Process name must be 50 characters or less');
        }
        if (data.working_day !== undefined && data.working_day < 0) {
            throw new Error('Working day must be a positive number');
        }
        if (data.due_time && !/^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/.test(data.due_time)) {
            throw new Error('Due time must be in HH:MM format');
        }
        return true;
    }

    validateProjectData(data) {
        if (!data.name || !data.name.trim()) {
            throw new Error('Project name is required');
        }
        if (data.name.length > 100) {
            throw new Error('Project name must be 100 characters or less');
        }
        return true;
    }

    /**
     * Show loading indicator
     */
    showLoading(message = 'Loading...') {
        const loadingId = 'loading-' + Date.now();
        const loadingElement = document.createElement('div');
        loadingElement.id = loadingId;
        loadingElement.className = 'flowcraft-loading';
        loadingElement.innerHTML = `
            <div class="loading-backdrop">
                <div class="loading-content">
                    <div class="loading-spinner"></div>
                    <div class="loading-text">${message}</div>
                </div>
            </div>
        `;
        
        document.body.appendChild(loadingElement);
        
        // Add loading styles if not already present
        if (!document.getElementById('flowcraft-loading-styles')) {
            this.addLoadingStyles();
        }
        
        return loadingId;
    }

    /**
     * Update loading message
     */
    updateLoadingMessage(loadingId, message) {
        const loadingElement = document.getElementById(loadingId);
        if (loadingElement) {
            const textElement = loadingElement.querySelector('.loading-text');
            if (textElement) {
                textElement.textContent = message;
            }
        }
    }

    /**
     * Hide loading indicator
     */
    hideLoading(loadingId) {
        const loadingElement = document.getElementById(loadingId);
        if (loadingElement) {
            loadingElement.remove();
        }
    }

    /**
     * Show notification to user
     */
    showNotification(message, type = 'info', duration = 5000) {
        const notification = document.createElement('div');
        notification.className = `flowcraft-notification notification-${type}`;
        
        const icon = this.getNotificationIcon(type);
        notification.innerHTML = `
            <div class="notification-content">
                <div class="notification-icon">${icon}</div>
                <div class="notification-message">${message}</div>
                <button class="notification-close" onclick="this.parentElement.parentElement.remove()">×</button>
            </div>
        `;
        
        document.body.appendChild(notification);
        
        // Add notification styles if not already present
        if (!document.getElementById('flowcraft-notification-styles')) {
            this.addNotificationStyles();
        }
        
        // Auto-remove after duration
        if (duration > 0) {
            setTimeout(() => {
                if (notification.parentElement) {
                    notification.remove();
                }
            }, duration);
        }
    }

    /**
     * Get notification icon based on type
     */
    getNotificationIcon(type) {
        const icons = {
            success: '✅',
            error: '❌',
            warning: '⚠️',
            info: 'ℹ️',
            validation: '⚠️'
        };
        return icons[type] || icons.info;
    }

    /**
     * Add loading styles
     */
    addLoadingStyles() {
        const styles = document.createElement('style');
        styles.id = 'flowcraft-loading-styles';
        styles.textContent = `
            .flowcraft-loading {
                position: fixed;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                z-index: 9999;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            
            .loading-backdrop {
                position: absolute;
                top: 0;
                left: 0;
                right: 0;
                bottom: 0;
                background: rgba(10, 10, 15, 0.8);
                backdrop-filter: blur(4px);
                display: flex;
                align-items: center;
                justify-content: center;
            }
            
            .loading-content {
                background: var(--fc-surface, rgba(26, 26, 46, 0.9));
                border: 2px solid var(--fc-border, rgba(0, 212, 255, 0.3));
                padding: 32px;
                text-align: center;
                box-shadow: var(--fc-glow-primary, 0 0 20px rgba(0, 212, 255, 0.5));
            }
            
            .loading-spinner {
                width: 32px;
                height: 32px;
                border: 3px solid var(--fc-border, rgba(0, 212, 255, 0.3));
                border-top: 3px solid var(--fc-neon-primary, #00D4FF);
                border-radius: 50%;
                animation: spin 1s linear infinite;
                margin: 0 auto 16px;
            }
            
            .loading-text {
                color: var(--fc-text-primary, #FFFFFF);
                font-family: 'JetBrains Mono', monospace;
                font-size: 14px;
                text-transform: uppercase;
                letter-spacing: 1px;
            }
            
            @keyframes spin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
        `;
        document.head.appendChild(styles);
    }

    /**
     * Add notification styles
     */
    addNotificationStyles() {
        const styles = document.createElement('style');
        styles.id = 'flowcraft-notification-styles';
        styles.textContent = `
            .flowcraft-notification {
                position: fixed;
                top: 20px;
                right: 20px;
                z-index: 10000;
                max-width: 400px;
                min-width: 300px;
                animation: slideIn 0.3s ease-out;
            }
            
            .notification-content {
                background: var(--fc-surface, rgba(26, 26, 46, 0.9));
                border: 2px solid var(--fc-border, rgba(0, 212, 255, 0.3));
                padding: 16px;
                display: flex;
                align-items: center;
                gap: 12px;
                backdrop-filter: blur(10px);
                box-shadow: var(--fc-shadow-deep, 0 25px 50px -12px rgba(0, 0, 0, 0.8));
            }
            
            .notification-icon {
                font-size: 20px;
                flex-shrink: 0;
            }
            
            .notification-message {
                color: var(--fc-text-primary, #FFFFFF);
                font-family: 'JetBrains Mono', monospace;
                font-size: 14px;
                flex-grow: 1;
                line-height: 1.4;
            }
            
            .notification-close {
                background: none;
                border: none;
                color: var(--fc-text-muted, #6B7280);
                font-size: 18px;
                cursor: pointer;
                padding: 4px;
                flex-shrink: 0;
                transition: color 0.2s;
            }
            
            .notification-close:hover {
                color: var(--fc-text-primary, #FFFFFF);
            }
            
            .notification-success .notification-content {
                border-color: var(--fc-neon-success, #39FF14);
                box-shadow: 0 0 20px rgba(57, 255, 20, 0.3);
            }
            
            .notification-error .notification-content {
                border-color: var(--fc-neon-secondary, #FF006E);
                box-shadow: 0 0 20px rgba(255, 0, 110, 0.3);
            }
            
            .notification-warning .notification-content {
                border-color: var(--fc-neon-warning, #FFBE0B);
                box-shadow: 0 0 20px rgba(255, 190, 11, 0.3);
            }
            
            .notification-validation .notification-content {
                border-color: var(--fc-neon-warning, #FFBE0B);
                box-shadow: 0 0 20px rgba(255, 190, 11, 0.3);
            }
            
            @keyframes slideIn {
                from {
                    transform: translateX(100%);
                    opacity: 0;
                }
                to {
                    transform: translateX(0);
                    opacity: 1;
                }
            }
        `;
        document.head.appendChild(styles);
    }

    /**
     * Utility function to sleep/delay
     */
    sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    /**
     * Enhanced HTML escaping to prevent XSS attacks
     * More comprehensive than the basic sanitizeInput
     */
    escapeHtml(unsafe) {
        if (typeof unsafe !== 'string') return unsafe;
        
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#x27;")
            .replace(/\//g, "&#x2F;");
    }

    /**
     * Sanitize input to prevent XSS (enhanced version)
     */
    sanitizeInput(input) {
        if (typeof input !== 'string') return input;
        
        // Use the enhanced HTML escaping
        return this.escapeHtml(input);
    }

    /**
     * Safe innerHTML replacement - creates DOM elements safely
     */
    safeSetInnerHTML(element, htmlContent) {
        if (!element) return;
        
        // Clear existing content
        element.innerHTML = '';
        
        // Create a temporary container
        const temp = document.createElement('div');
        temp.innerHTML = htmlContent;
        
        // Move sanitized content to target element
        while (temp.firstChild) {
            element.appendChild(temp.firstChild);
        }
    }

    /**
     * Create safe HTML element with escaped content
     */
    createSafeElement(tagName, textContent, attributes = {}) {
        const element = document.createElement(tagName);
        
        // Set text content safely
        if (textContent) {
            element.textContent = textContent;
        }
        
        // Set attributes safely
        Object.entries(attributes).forEach(([key, value]) => {
            element.setAttribute(key, this.escapeHtml(value.toString()));
        });
        
        return element;
    }

    /**
     * Debounce function for search inputs
     */
    debounce(func, wait) {
        let timeout;
        return function executedFunction(...args) {
            const later = () => {
                clearTimeout(timeout);
                func(...args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
        };
    }

    /**
     * Check if user is authenticated
     */
    async checkAuth(supabaseClient) {
        try {
            const { data: { user }, error } = await supabaseClient.auth.getUser();
            
            if (error) {
                throw error;
            }
            
            return user;
        } catch (error) {
            console.log('Auth check failed:', error);
            return null;
        }
    }

    /**
     * Redirect to login if not authenticated
     */
    redirectToLogin() {
        const currentPage = window.location.pathname;
        const loginPages = ['index.html', 'confirm.html', 'reset.html'];
        
        // Don't redirect if already on a login page
        if (loginPages.some(page => currentPage.includes(page))) {
            return;
        }
        
        window.location.href = 'index.html';
    }

    /**
     * CSRF Protection - Add CSRF token to forms
     */
    addCSRFToken(form) {
        if (!form || !window.FlowCraftCSRF) return;
        
        // Remove existing CSRF token if any
        const existingToken = form.querySelector('input[name="csrf_token"]');
        if (existingToken) {
            existingToken.remove();
        }
        
        // Add new CSRF token
        const tokenInput = document.createElement('input');
        tokenInput.type = 'hidden';
        tokenInput.name = 'csrf_token';
        tokenInput.value = window.FlowCraftCSRF.getToken();
        form.appendChild(tokenInput);
    }

    /**
     * Validate CSRF token
     */
    validateCSRFToken(token) {
        if (!window.FlowCraftCSRF) return false;
        return window.FlowCraftCSRF.validateToken(token);
    }

    /**
     * Rate limiting check for authentication attempts
     */
    checkRateLimit(identifier, type = 'login') {
        if (!window.FlowCraftRateLimit) return true;
        
        const config = window.FlowCraftConfig?.security?.rateLimit || {};
        let maxAttempts, lockoutDuration;
        
        switch (type) {
            case 'login':
                maxAttempts = config.maxLoginAttempts || 5;
                lockoutDuration = config.lockoutDuration || 15 * 60 * 1000;
                break;
            case 'password_reset':
                maxAttempts = config.maxPasswordResetAttempts || 3;
                lockoutDuration = config.passwordResetCooldown || 5 * 60 * 1000;
                break;
            default:
                maxAttempts = 5;
                lockoutDuration = 15 * 60 * 1000;
        }
        
        if (window.FlowCraftRateLimit.isLocked(identifier)) {
            const remaining = Math.ceil((window.FlowCraftRateLimit.lockouts.get(identifier) - Date.now()) / 1000 / 60);
            throw new Error(`Too many attempts. Try again in ${remaining} minutes.`);
        }
        
        return window.FlowCraftRateLimit.recordAttempt(identifier, maxAttempts, lockoutDuration);
    }

    /**
     * Clear rate limit for successful authentication
     */
    clearRateLimit(identifier) {
        if (window.FlowCraftRateLimit) {
            window.FlowCraftRateLimit.clearAttempts(identifier);
        }
    }

    /**
     * Enhanced form validation with security checks
     */
    validateForm(form) {
        if (!form) return false;
        
        // Check CSRF token
        const csrfToken = form.querySelector('input[name="csrf_token"]');
        if (!csrfToken || !this.validateCSRFToken(csrfToken.value)) {
            throw new Error('Security validation failed. Please refresh the page and try again.');
        }
        
        // Validate all inputs
        const inputs = form.querySelectorAll('input, textarea, select');
        for (const input of inputs) {
            if (input.required && !input.value.trim()) {
                throw new Error(`${input.name || 'Field'} is required`);
            }
            
            // Sanitize input values
            if (input.type === 'text' || input.type === 'email' || input.tagName === 'TEXTAREA') {
                input.value = this.sanitizeInput(input.value);
            }
        }
        
        return true;
    }

    /**
     * Session timeout management
     */
    initSessionTimeout(timeoutMinutes = 30) {
        let timeoutId;
        let warningShown = false;
        
        const resetTimeout = () => {
            clearTimeout(timeoutId);
            warningShown = false;
            
            timeoutId = setTimeout(() => {
                if (!warningShown) {
                    warningShown = true;
                    const extend = confirm('Your session will expire in 5 minutes. Do you want to extend it?');
                    if (extend) {
                        resetTimeout();
                        return;
                    }
                }
                
                // Auto logout
                this.showNotification('Session expired. Please login again.', 'warning');
                setTimeout(() => {
                    window.location.href = 'index.html';
                }, 3000);
            }, timeoutMinutes * 60 * 1000);
        };
        
        // Reset timeout on user activity
        ['click', 'keypress', 'scroll', 'mousemove'].forEach(event => {
            document.addEventListener(event, resetTimeout, { passive: true });
        });
        
        // Initial timeout
        resetTimeout();
    }
}

// Create global instance
window.FlowCraftErrorHandler = new FlowCraftErrorHandler();

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = FlowCraftErrorHandler;
}