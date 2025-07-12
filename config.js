/**
 * FlowCraft Configuration
 * Secure configuration management for FlowCraft application
 */

// Security Configuration
const FlowCraftConfig = {
    // Environment detection
    isDevelopment: window.location.hostname === 'localhost' || 
                   window.location.hostname === '127.0.0.1' ||
                   window.location.protocol === 'file:' ||
                   window.location.port === '8000',
    
    // Supabase Configuration
    supabase: {
        // These should be loaded from environment variables or a secure config service
        // For now, we'll use a more secure approach than hardcoding in each file
        url: window.FLOWCRAFT_SUPABASE_URL || 'https://hbwnghrfhyikcywixjqn.supabase.co',
        anonKey: window.FLOWCRAFT_SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhid25naHJmaHlpa2N5d2l4anFuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTEyMjE4MzMsImV4cCI6MjA2Njc5NzgzM30.IOEcWblDku7LlmfsEzF0j39rkyFhcJQWEm6TsFpNv2w'
    },
    
    // Security Settings
    security: {
        // CSRF Protection
        csrf: {
            enabled: true,
            tokenName: 'flowcraft_csrf_token',
            headerName: 'X-CSRF-Token'
        },
        
        // Rate Limiting
        rateLimit: {
            maxLoginAttempts: 5,
            lockoutDuration: 15 * 60 * 1000, // 15 minutes
            maxPasswordResetAttempts: 3,
            passwordResetCooldown: 5 * 60 * 1000 // 5 minutes
        },
        
        // Password Policy
        password: {
            minLength: 12,
            requireUppercase: true,
            requireLowercase: true,
            requireNumbers: true,
            requireSpecialChars: true,
            forbiddenPasswords: ['password', 'flowcraft', '123456', 'qwerty']
        },
        
        // XSS Protection
        xss: {
            enabled: true,
            strictMode: true
        }
    },
    
    // Session Management
    session: {
        timeoutMinutes: 30,
        warningMinutes: 5,
        autoLogout: true
    },
    
    // Email Service Configuration (Resend)
    email: {
        // Resend API configuration
        apiKey: window.FLOWCRAFT_RESEND_API_KEY || null,
        fromEmail: window.FLOWCRAFT_FROM_EMAIL || 'noreply@flowcraft.app',
        fromName: window.FLOWCRAFT_FROM_NAME || 'FlowCraft',
        
        // Email templates
        templates: {
            projectInvitation: {
                subject: 'You\'ve been invited to collaborate on a FlowCraft project',
                template: 'project-invitation',
                html: `
                    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background-color: #0A0A0F; color: #FFFFFF; padding: 20px; border-radius: 10px;">
                        <h2 style="color: #00D4FF; text-align: center;">🚀 FlowCraft Project Invitation</h2>
                        <p>Hello!</p>
                        <p>You've been invited to collaborate on the project <strong>{{projectName}}</strong> with <strong>{{role}}</strong> access.</p>
                        <p>Invited by: {{inviterEmail}}</p>
                        {{#if customMessage}}
                        <div style="background-color: #1A1A2E; padding: 15px; border-radius: 5px; margin: 15px 0;">
                            <p><strong>Personal message:</strong></p>
                            <p>{{customMessage}}</p>
                        </div>
                        {{/if}}
                        <div style="text-align: center; margin: 30px 0;">
                            <a href="{{invitationUrl}}" style="background: linear-gradient(135deg, #00D4FF 0%, #FF006E 100%); color: white; padding: 15px 30px; text-decoration: none; border-radius: 5px; font-weight: bold;">Accept Invitation</a>
                        </div>
                        <p><strong>Don't have an account?</strong> No problem! You can register for free at <a href="{{siteUrl}}" style="color: #00D4FF;">FlowCraft</a> and then accept your invitation.</p>
                        <p style="color: #6B7280; font-size: 12px; margin-top: 20px;">This invitation will expire in 7 days. If you didn't expect this invitation, you can safely ignore this email.</p>
                    </div>
                `
            },
            invitationAccepted: {
                subject: 'Project invitation accepted',
                template: 'invitation-accepted'
            }
        }
    }
};

// CSRF Token Management
class CSRFManager {
    constructor() {
        this.token = null;
        this.generateToken();
    }
    
    generateToken() {
        // Generate a secure random token
        const array = new Uint8Array(32);
        crypto.getRandomValues(array);
        this.token = Array.from(array, byte => byte.toString(16).padStart(2, '0')).join('');
        
        // Store in meta tag for form access
        let metaTag = document.querySelector('meta[name="csrf-token"]');
        if (!metaTag) {
            metaTag = document.createElement('meta');
            metaTag.name = 'csrf-token';
            document.head.appendChild(metaTag);
        }
        metaTag.content = this.token;
        
        // Store in localStorage with timestamp
        localStorage.setItem('flowcraft_csrf_token', this.token);
        localStorage.setItem('flowcraft_csrf_token_time', Date.now().toString());
    }
    
    getToken() {
        // Check if token is still valid (24 hours)
        const tokenTime = localStorage.getItem('flowcraft_csrf_token_time');
        if (!tokenTime || Date.now() - parseInt(tokenTime) > 24 * 60 * 60 * 1000) {
            this.generateToken();
        }
        return this.token;
    }
    
    validateToken(token) {
        return token === this.token;
    }
}

// Initialize CSRF Manager
window.FlowCraftCSRF = new CSRFManager();

// Rate Limiting Manager
class RateLimitManager {
    constructor() {
        this.attempts = new Map();
        this.lockouts = new Map();
    }
    
    isLocked(identifier) {
        const lockout = this.lockouts.get(identifier);
        if (lockout && Date.now() < lockout) {
            return true;
        }
        if (lockout && Date.now() >= lockout) {
            this.lockouts.delete(identifier);
            this.attempts.delete(identifier);
        }
        return false;
    }
    
    recordAttempt(identifier, maxAttempts = 5, lockoutDuration = 15 * 60 * 1000) {
        if (this.isLocked(identifier)) {
            return false;
        }
        
        const currentAttempts = this.attempts.get(identifier) || 0;
        const newAttempts = currentAttempts + 1;
        
        this.attempts.set(identifier, newAttempts);
        
        if (newAttempts >= maxAttempts) {
            this.lockouts.set(identifier, Date.now() + lockoutDuration);
            return false;
        }
        
        return true;
    }
    
    clearAttempts(identifier) {
        this.attempts.delete(identifier);
        this.lockouts.delete(identifier);
    }
    
    getRemainingAttempts(identifier, maxAttempts = 5) {
        const currentAttempts = this.attempts.get(identifier) || 0;
        return Math.max(0, maxAttempts - currentAttempts);
    }
}

// Initialize Rate Limit Manager
window.FlowCraftRateLimit = new RateLimitManager();

// Export configuration
window.FlowCraftConfig = FlowCraftConfig;

// Security Helper Functions
window.FlowCraftSecurity = {
    // Get secure Supabase configuration
    getSupabaseConfig() {
        return {
            url: FlowCraftConfig.supabase.url,
            anonKey: FlowCraftConfig.supabase.anonKey
        };
    },
    
    // Check if credentials are properly configured
    validateConfiguration() {
        const config = FlowCraftConfig.supabase;
        if (!config.url || !config.anonKey) {
            console.error('FlowCraft: Supabase configuration is missing');
            return false;
        }
        
        // Warn if using default credentials in production
        if (!FlowCraftConfig.isDevelopment && 
            config.url === 'https://hbwnghrfhyikcywixjqn.supabase.co') {
            console.warn('FlowCraft: Using default credentials in production environment');
        }
        
        return true;
    }
};

// Initialize configuration validation
if (!window.FlowCraftSecurity.validateConfiguration()) {
    console.error('FlowCraft: Configuration validation failed');
}

console.log('FlowCraft Security Configuration loaded successfully');