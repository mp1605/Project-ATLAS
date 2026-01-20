// Notification dropdown functionality

function toggleNotifications() {
    const dropdown = document.getElementById('notificationsDropdown');
    dropdown.classList.toggle('active');

    // Close dropdown when clicking outside
    if (dropdown.classList.contains('active')) {
        setTimeout(() => {
            document.addEventListener('click', closeNotificationsOutside);
        }, 0);
    } else {
        document.removeEventListener('click', closeNotificationsOutside);
    }
}

function closeNotificationsOutside(event) {
    const dropdown = document.getElementById('notificationsDropdown');
    const notificationContainer = document.querySelector('.notification-container');

    if (!notificationContainer.contains(event.target)) {
        dropdown.classList.remove('active');
        document.removeEventListener('click', closeNotificationsOutside);
    }
}

function markAllRead() {
    // Mark all notifications as read
    const badge = document.getElementById('notificationBadge');
    badge.style.display = 'none';

    // Remove notification dots
    const dots = document.querySelectorAll('.notification-dot');
    dots.forEach(dot => {
        dot.style.opacity = '0.3';
    });

    console.log('All notifications marked as read');
}

// Initialize notification count
document.addEventListener('DOMContentLoaded', function () {
    const notificationItems = document.querySelectorAll('.notification-item');
    const badge = document.getElementById('notificationBadge');

    if (notificationItems.length === 0) {
        badge.style.display = 'none';
    } else {
        badge.textContent = notificationItems.length;
    }
});
