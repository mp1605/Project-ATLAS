/**
 * Settings Page JavaScript
 * Handles tab navigation, form submissions, and settings management
 */

let currentUser = null;

// Initialize on page load
document.addEventListener('DOMContentLoaded', async () => {
    // Check authentication
    if (!checkAuth()) {
        window.location.href = 'login.html';
        return;
    }

    // Load user data
    currentUser = getUserData();

    // Initialize tabs
    initializeTabs();

    // Load settings
    await loadSettings();

    // Setup form handlers
    setupFormHandlers();

    // Check if user is admin
    if (currentUser && currentUser.role === 'admin') {
        document.getElementById('adminTab').style.display = 'flex';
    }
});

/**
 * Initialize tab navigation
 */
function initializeTabs() {
    const tabs = document.querySelectorAll('.settings-tab');
    const tabContents = document.querySelectorAll('.tab-content');

    tabs.forEach(tab => {
        tab.addEventListener('click', () => {
            const targetTab = tab.dataset.tab;

            // Remove active class from all tabs
            tabs.forEach(t => t.classList.remove('active'));
            tabContents.forEach(tc => {
                tc.style.display = 'none';
                tc.classList.remove('active');
            });

            // Add active class to clicked tab
            tab.classList.add('active');

            // Show corresponding content
            // Map tab names to actual element IDs
            const tabIdMap = {
                'profile': 'profileTab',
                'notifications': 'notificationsTab',
                'display': 'displayTab',
                'security': 'securityTab',
                'admin': 'adminTabContent'
            };

            const targetContent = document.getElementById(tabIdMap[targetTab]);
            if (targetContent) {
                targetContent.style.display = 'block';
                targetContent.classList.add('active');
                setTimeout(() => targetContent.classList.add('animate-fadeIn'), 10);
            }
        });
    });
}

/**
 * Load user settings from API
 */
async function loadSettings() {
    try {
        const response = await fetch(`${getAPIUrl()}/settings`, {
            headers: {
                'Authorization': `Bearer ${getToken()}`
            }
        });

        if (!response.ok) {
            // If no settings exist, populate with defaults
            if (response.status === 404) {
                populateDefaultSettings();
                return;
            }
            throw new Error('Failed to load settings');
        }

        const data = await response.json();
        populateSettings(data);
    } catch (error) {
        console.error('Error loading settings:', error);
        populateDefaultSettings();
    }
}

/**
 * Populate form with settings data
 */
function populateSettings(data) {
    // Profile
    if (data.profile || currentUser) {
        const profile = data.profile || currentUser;
        document.getElementById('fullName').value = profile.name || '';
        document.getElementById('email').value = profile.email || '';
        document.getElementById('role').value = profile.role || 'user';
        document.getElementById('username').value = profile.username || '';

        if (profile.photo) {
            const photoPreview = document.getElementById('photoPreview');
            photoPreview.innerHTML = `<img src="${profile.photo}" alt="Profile">`;
            document.getElementById('removePhotoBtn').style.display = 'inline-block';
        }
    }

    // Notifications
    if (data.notifications) {
        document.getElementById('emailNotifications').checked = data.notifications.email !== false;
        document.getElementById('criticalThreshold').value = data.notifications.thresholds?.critical || 40;
        document.getElementById('warningThreshold').value = data.notifications.thresholds?.warning || 60;
        document.getElementById('sleepDebtThreshold').value = data.notifications.thresholds?.sleep_debt || 12;

        const frequency = data.notifications.frequency || 'immediate';
        document.querySelector(`input[name="frequency"][value="${frequency}"]`).checked = true;
    }

    // Display
    if (data.display) {
        const theme = data.display.theme || 'dark';
        document.querySelector(`input[name="theme"][value="${theme}"]`).checked = true;
        document.getElementById('defaultView').value = data.display.defaultView || 'dashboard';
        document.getElementById('timezone').value = data.display.timezone || 'America/Chicago';
        document.getElementById('dateFormat').value = data.display.dateFormat || 'MM/DD/YYYY';
    }

    // Last login
    if (data.lastLogin) {
        document.getElementById('lastLogin').textContent = formatTimeAgo(new Date(data.lastLogin));
    }
}

/**
 * Populate default settings
 */
function populateDefaultSettings() {
    if (currentUser) {
        document.getElementById('fullName').value = currentUser.name || '';
        document.getElementById('email').value = currentUser.email || '';
        document.getElementById('role').value = currentUser.role || 'user';
    }
}

/**
 * Setup form submission handlers
 */
function setupFormHandlers() {
    // Profile form
    document.getElementById('profileForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await saveProfile();
    });

    // Notifications form
    document.getElementById('notificationsForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await saveNotifications();
    });

    // Display form
    document.getElementById('displayForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await saveDisplay();
    });

    // Password form
    document.getElementById('passwordForm').addEventListener('submit', async (e) => {
        e.preventDefault();
        await changePassword();
    });

    // Photo upload
    document.getElementById('photoUpload').addEventListener('change', handlePhotoUpload);

    // Remove photo
    document.getElementById('removePhotoBtn').addEventListener('click', removePhoto);
}

/**
 * Save profile settings
 */
async function saveProfile() {
    const formData = {
        name: document.getElementById('fullName').value,
        username: document.getElementById('username').value
    };

    try {
        const response = await fetch(`${getAPIUrl()}/settings/profile`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getToken()}`
            },
            body: JSON.stringify(formData)
        });

        if (!response.ok) throw new Error('Failed to save profile');

        const data = await response.json();

        // Update stored user data
        currentUser.name = formData.name;
        localStorage.setItem('user', JSON.stringify(currentUser));

        showSuccess('Profile updated successfully!');
    } catch (error) {
        console.error('Error saving profile:', error);
        showError('Failed to save profile. Please try again.');
    }
}

/**
 * Save notification preferences
 */
async function saveNotifications() {
    const formData = {
        email: document.getElementById('emailNotifications').checked,
        thresholds: {
            critical: parseInt(document.getElementById('criticalThreshold').value),
            warning: parseInt(document.getElementById('warningThreshold').value),
            sleep_debt: parseInt(document.getElementById('sleepDebtThreshold').value)
        },
        frequency: document.querySelector('input[name="frequency"]:checked').value
    };

    try {
        const response = await fetch(`${getAPIUrl()}/settings/notifications`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getToken()}`
            },
            body: JSON.stringify(formData)
        });

        if (!response.ok) throw new Error('Failed to save notifications');

        showSuccess('Notification preferences saved!');
    } catch (error) {
        console.error('Error saving notifications:', error);
        showError('Failed to save notification preferences.');
    }
}

/**
 * Save display settings
 */
async function saveDisplay() {
    const formData = {
        theme: document.querySelector('input[name="theme"]:checked').value,
        defaultView: document.getElementById('defaultView').value,
        timezone: document.getElementById('timezone').value,
        dateFormat: document.getElementById('dateFormat').value
    };

    try {
        const response = await fetch(`${getAPIUrl()}/settings/display`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getToken()}`
            },
            body: JSON.stringify(formData)
        });

        if (!response.ok) throw new Error('Failed to save display settings');

        showSuccess('Display settings saved!');
    } catch (error) {
        console.error('Error saving display settings:', error);
        showError('Failed to save display settings.');
    }
}

/**
 * Change password
 */
async function changePassword() {
    const currentPassword = document.getElementById('currentPassword').value;
    const newPassword = document.getElementById('newPassword').value;
    const confirmPassword = document.getElementById('confirmPassword').value;

    // Validate
    if (newPassword !== confirmPassword) {
        showError('New passwords do not match!');
        return;
    }

    if (newPassword.length < 6) {
        showError('Password must be at least 6 characters long!');
        return;
    }

    try {
        const response = await fetch(`${getAPIUrl()}/settings/password`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${getToken()}`
            },
            body: JSON.stringify({
                currentPassword,
                newPassword
            })
        });

        if (!response.ok) {
            const error = await response.json();
            throw new Error(error.message || 'Failed to change password');
        }

        // Clear form
        document.getElementById('passwordForm').reset();
        showSuccess('Password changed successfully!');
    } catch (error) {
        console.error('Error changing password:', error);
        showError(error.message || 'Failed to change password.');
    }
}

/**
 * Handle photo upload
 */
async function handlePhotoUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    // Validate file type
    if (!file.type.startsWith('image/')) {
        showError('Please select an image file');
        return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
        showError('Image size must be less than 5MB');
        return;
    }

    // Preview image
    const reader = new FileReader();
    reader.onload = (event) => {
        const photoPreview = document.getElementById('photoPreview');
        photoPreview.innerHTML = `<img src="${event.target.result}" alt="Profile">`;
        document.getElementById('removePhotoBtn').style.display = 'inline-block';
    };
    reader.readAsDataURL(file);

    // Upload to server
    const formData = new FormData();
    formData.append('photo', file);

    try {
        const response = await fetch(`${getAPIUrl()}/settings/upload-photo`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${getToken()}`
            },
            body: formData
        });

        if (!response.ok) throw new Error('Failed to upload photo');

        const data = await response.json();
        showSuccess('Profile photo updated!');
    } catch (error) {
        console.error('Error uploading photo:', error);
        showError('Failed to upload photo. Using preview only.');
    }
}

/**
 * Remove photo
 */
function removePhoto() {
    const photoPreview = document.getElementById('photoPreview');
    photoPreview.innerHTML = `
        <svg viewBox="0 0 24 24" width="80" height="80">
            <path fill="#94a3b8"
                d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />
        </svg>
    `;
    document.getElementById('removePhotoBtn').style.display = 'none';
    document.getElementById('photoUpload').value = '';
}

/**
 * Format time ago helper
 */
function formatTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000);

    if (seconds < 60) return 'Just now';
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    const days = Math.floor(hours / 24);
    return `${days} day${days > 1 ? 's' : ''} ago`;
}

/**
 * Logout function
 */
function logout() {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    window.location.href = 'login.html';
}

// ==========================================
// PRIVACY FEATURES
// ==========================================

async function handleExportData() {
    try {
        const token = localStorage.getItem('token');
        const response = await fetch('/api/v1/settings/export-data', {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) {
            throw new Error('Failed to export data');
        }

        // Get the blob from response
        const blob = await response.blob();

        // Create download link
        const url = window.URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `auix-data-export-${Date.now()}.json`;
        document.body.appendChild(a);
        a.click();
        window.URL.revokeObjectURL(url);
        document.body.removeChild(a);

        showSuccess('Data exported successfully!');
    } catch (error) {
        console.error('Export data error:', error);
        showError('Failed to export data. Please try again.');
    }
}

async function handleDeleteAccount() {
    // Show confirmation dialog
    const confirmed = confirm(
        'Are you absolutely sure you want to delete your account?\n\n' +
        'This action CANNOT be undone. All your data will be permanently deleted.\n\n' +
        'Please enter your password in the next prompt to confirm deletion.'
    );

    if (!confirmed) {
        return;
    }

    // Prompt for password
    const password = prompt('Enter your password to confirm account deletion:');

    if (!password) {
        showSuccess('Account deletion cancelled');
        return;
    }

    try {
        const token = localStorage.getItem('token');
        const response = await fetch('/api/v1/settings/delete-account', {
            method: 'DELETE',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify({ password })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.error || 'Failed to delete account');
        }

        showSuccess('Account deleted successfully. Redirecting to login...');

        // Clear local storage and redirect to login
        setTimeout(() => {
            localStorage.removeItem('token');
            localStorage.removeItem('user');
            window.location.href = '/login.html';
        }, 2000);
    } catch (error) {
        console.error('Delete account error:', error);
        showError(error.message || 'Failed to delete account. Please try again.');
    }
}

// Add event listeners for privacy features
document.addEventListener('DOMContentLoaded', () => {
    const exportDataBtn = document.getElementById('exportDataBtn');
    if (exportDataBtn) {
        exportDataBtn.addEventListener('click', handleExportData);
    }

    const deleteAccountBtn = document.getElementById('deleteAccountBtn');
    if (deleteAccountBtn) {
        deleteAccountBtn.addEventListener('click', handleDeleteAccount);
    }
});
