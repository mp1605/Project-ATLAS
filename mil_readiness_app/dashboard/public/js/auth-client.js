/**
 * Dashboard Authentication Client
 * Handles login, token storage, and auth state management
 * NO HARDCODED TOKENS - tokens stored in localStorage only
 */

class AuthClient {
    constructor(apiBaseUrl) {
        this.apiBaseUrl = apiBaseUrl;
        this.tokenKey = 'admin_token';
    }

    /**
     * Login with email/password
     * Stores JWT token in localStorage on success
     */
    async login(email, password) {
        try {
            const response = await fetch(`${this.apiBaseUrl}/api/v1/auth/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ email, password })
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.error || 'Login failed');
            }

            const data = await response.json();

            // Store token in localStorage (secure for HTTPS)
            localStorage.setItem(this.tokenKey, data.token);
            localStorage.setItem('user_email', data.user.email);
            localStorage.setItem('user_role', data.user.role);

            console.log('✅ Login successful:', data.user.email);

            return data;
        } catch (error) {
            console.error('❌ Login failed:', error);
            throw error;
        }
    }

    /**
     * Get stored JWT token
     */
    getToken() {
        return localStorage.getItem(this.tokenKey);
    }

    /**
     * Get user info from localStorage
     */
    getUserInfo() {
        return {
            email: localStorage.getItem('user_email'),
            role: localStorage.getItem('user_role')
        };
    }

    /**
     * Logout - clear all auth data
     */
    logout() {
        localStorage.removeItem(this.tokenKey);
        localStorage.removeItem('user_email');
        localStorage.removeItem('user_role');
        console.log('✅ Logged out');
    }

    /**
     * Check if user is authenticated
     */
    isAuthenticated() {
        const token = this.getToken();
        if (!token) return false;

        // Check if token is expired (basic check)
        try {
            const payload = JSON.parse(atob(token.split('.')[1]));
            const expiry = payload.exp * 1000; // Convert to milliseconds
            return Date.now() < expiry;
        } catch (e) {
            return false;
        }
    }

    /**
     * Require authentication - redirect to login if not authenticated
     */
    requireAuth() {
        if (!this.isAuthenticated()) {
            window.location.href = '/login.html';
            return false;
        }
        return true;
    }

    /**
     * Handle 401/403 responses - logout and redirect
     */
    handleUnauthorized() {
        console.warn('⚠️ Unauthorized - logging out');
        this.logout();
        window.location.href = '/login.html';
    }

    /**
     * Make authenticated API request
     */
    async fetchWithAuth(url, options = {}) {
        const token = this.getToken();

        if (!token) {
            this.handleUnauthorized();
            throw new Error('No auth token');
        }

        const response = await fetch(url, {
            ...options,
            headers: {
                ...options.headers,
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            }
        });

        // Handle unauthorized responses
        if (response.status === 401 || response.status === 403) {
            this.handleUnauthorized();
            throw new Error('Unauthorized');
        }

        return response;
    }
}

// Export for use in other scripts
const authClient = new AuthClient('http://localhost:3000'); // TODO: Update for production
