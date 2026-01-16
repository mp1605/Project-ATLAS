// API Base URL
const API_URL = 'http://localhost:3000/api';

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
            setToken(data.token);
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
    event.preventDefault();

    const name = document.getElementById('signup-name')?.value;
    const email = document.getElementById('signup-email')?.value;
    const password = document.getElementById('signup-password')?.value;
    const confirmPassword = document.getElementById('signup-confirm-password')?.value;

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
        const response = await fetch(`${API_URL}/auth/register`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ email, password, name })
        });

        const data = await response.json();

        if (response.ok) {
            setToken(data.token);
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

// Initialize auth listeners when DOM is ready
document.addEventListener('DOMContentLoaded', () => {
    // Login form
    const loginForm = document.getElementById('login-form');
    if (loginForm) {
        loginForm.addEventListener('submit', handleLogin);
    }

    // Sign up form
    const signupForm = document.getElementById('signup-form');
    if (signupForm) {
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
});
