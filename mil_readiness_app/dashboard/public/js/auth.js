// API Base URL - Use computer's IP if not on localhost
const getAPIUrl = () => {
    const hostname = window.location.hostname;
    // Since we are served BY the backend on port 8000, we can just use relative path /api/v1
    // But if developing separately, we might need absolute URL.
    // Let's deduce based on port.

    if (window.location.port === '8000') {
        return '/api/v1'; // Relative path if served by FastAPI
    }

    if (hostname === 'localhost' || hostname === '127.0.0.1') {
        return 'http://localhost:8000/api/v1';
    }
    if (!hostname || hostname === '') {
        return 'http://localhost:8000/api/v1';
    }
    return `http://${hostname}:8000/api/v1`;
};

const API_URL = getAPIUrl();
window.API_URL = API_URL; // Make global
console.log('Using API_URL:', API_URL);

// Get token from localStorage
function getToken() {
    return localStorage.getItem('auth_token');
}

// Set token in localStorage
function setToken(token) {
    localStorage.setItem('auth_token', token);
}

// Remove token from localStorage
function removeToken() {
    localStorage.removeItem('auth_token');
}

// Get user from localStorage
function getUser() {
    const userStr = localStorage.getItem('user');
    return userStr ? JSON.parse(userStr) : null;
}

// Set user in localStorage
function setUser(user) {
    localStorage.setItem('user', JSON.stringify(user));
}

// Show error message
function showError(message) {
    const errorDiv = document.getElementById('error-message');
    if (errorDiv) {
        errorDiv.textContent = message;
        errorDiv.style.display = 'block';
        setTimeout(() => {
            errorDiv.style.display = 'none';
        }, 5000);
    } else {
        alert(message);
    }
}

// Show success message
function showSuccess(message) {
    const successDiv = document.getElementById('success-message');
    if (successDiv) {
        successDiv.textContent = message;
        successDiv.style.display = 'block';
        setTimeout(() => {
            successDiv.style.display = 'none';
        }, 3000);
    } else {
        alert(message);
    }
}

// Handle Login
async function handleLogin(event) {
    event.preventDefault();

    const email = document.getElementById('email')?.value;
    const password = document.getElementById('password')?.value;

    // Reset messages
    const errorDiv = document.getElementById('error-message');
    const successDiv = document.getElementById('success-message');
    if (errorDiv) errorDiv.style.display = 'none';
    if (successDiv) successDiv.style.display = 'none';

    if (!email || !password) {
        showError('Please enter both email and password');
        return;
    }

    try {
        const response = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email, password })
        });

        const data = await response.json();

        if (response.ok) {
            setToken(data.access_token);
            setUser(data.user);
            showSuccess('Login successful! Redirecting...');
            setTimeout(() => {
                window.location.href = 'Dashboard.html';
            }, 1000);
        } else {
            showError(data.error || 'Login failed');
        }
    } catch (error) {
        console.error('Login error:', error);
        showError('Network error. Please try again.');
    }
}

// Handle Registration
async function handleRegister(event) {
    console.log('Signup form submission detected');
    event.preventDefault();

    const email = document.getElementById('signup-email')?.value;
    const password = document.getElementById('signup-password')?.value;
    const confirmPassword = document.getElementById('signup-confirm-password')?.value;
    const invite_code = document.getElementById('signup-invite-code')?.value;

    // Reset messages
    const errorDiv = document.getElementById('error-message');
    const successDiv = document.getElementById('success-message');
    if (errorDiv) errorDiv.style.display = 'none';
    if (successDiv) successDiv.style.display = 'none';

    if (!email || !password) {
        showError('Email and password are required');
        return;
    }

    if (password !== confirmPassword) {
        showError('Passwords do not match');
        return;
    }

    if (password.length < 6) {
        showError('Password must be at least 6 characters');
        return;
    }

    try {
        console.log('Attempting registration for:', email);
        const response = await fetch(`${API_URL}/auth/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                email,
                password,
                role: 'ADMIN', // Dashboard users are always admins
                invite_code
            })
        });

        const data = await response.json();

        if (response.ok) {
            setToken(data.access_token);
            setUser(data.user);
            showSuccess('Registration successful! Redirecting...');
            setTimeout(() => {
                window.location.href = 'Dashboard.html';
            }, 1000);
        } else {
            showError(data.error || 'Registration failed');
        }
    } catch (error) {
        console.error('Registration error:', error);
        showError('Network error. Please try again.');
    }
}

// Check if user is authenticated
function checkAuth() {
    const token = getToken();
    if (!token && !window.location.pathname.includes('login.html')) {
        window.location.href = 'login.html';
        return false;
    }
    return true;
}

// Logout function
function logout() {
    removeToken();
    localStorage.removeItem('user');
    window.location.href = 'login.html';
}

// Initialize auth listeners
function initAuth() {
    console.log('Initializing Auth Listeners...');

    // Login form
    const loginForm = document.getElementById('login-form');
    if (loginForm) {
        console.log('Attaching Login Listener');
        loginForm.addEventListener('submit', handleLogin);
    }

    // Sign up form
    const signupForm = document.getElementById('signup-form');
    if (signupForm) {
        console.log('Attaching Signup Listener');
        signupForm.addEventListener('submit', handleRegister);
    }

    // Logout links
    const logoutLinks = document.querySelectorAll('[href="login.html"]');
    logoutLinks.forEach(link => {
        if (link.textContent.toLowerCase().includes('logout')) {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                logout();
            });
        }
    });

    // Run auth check
    checkAuth();
}

// Run initialization
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initAuth);
} else {
    initAuth();
}
