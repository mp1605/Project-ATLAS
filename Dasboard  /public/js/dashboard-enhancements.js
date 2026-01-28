/**
 * Dashboard Enhancements
 * Additional animations and interactions for the dashboard
 */

// Animate progress bars on page load
document.addEventListener('DOMContentLoaded', () => {
    // Animate status bar fills
    setTimeout(() => {
        document.querySelectorAll('[data-width]').forEach(fill => {
            const targetWidth = fill.dataset.width;
            fill.style.width = `${targetWidth}%`;
        });
    }, 500);

    // Add live sync indicator
    addLiveSyncIndicator();
});

/**
 * Add live sync indicator to header
 */
function addLiveSyncIndicator() {
    const headerActions = document.querySelector('.header-actions');
    if (!headerActions) return;

    const syncIndicator = document.createElement('div');
    syncIndicator.className = 'sync-indicator';
    syncIndicator.innerHTML = `
        <div class="sync-status" title="Last synced: Just now">
            <div class="sync-dot animate-pulseRing" style="
                width: 8px;
                height: 8px;
                background: #10b981;
                border-radius: 50%;
                margin-right: 8px;
            "></div>
            <span style="font-size: 0.75rem; color: #94a3b8; text-transform: uppercase; letter-spacing: 0.5px;">
                Synced
            </span>
        </div>
    `;
    syncIndicator.style.display = 'flex';
    syncIndicator.style.alignItems = 'center';
    syncIndicator.style.marginRight = '15px';

    headerActions.insertBefore(syncIndicator, headerActions.firstChild);
}

/**
 * Simulate live data update (for demo purposes)
 */
function simulateLiveUpdate() {
    // Update stat cards with new values
    const updates = {
        totalPersonnel: 185,
        readyDeployment: 122,
        medicalIssues: 24,
        sleepDebtDays: 7
    };

    Object.entries(updates).forEach(([id, value]) => {
        const element = document.getElementById(id);
        if (element && element.dataset.count) {
            element.dataset.count = value;
            const scoreCard = element.closest('[data-score-card]');
            if (scoreCard) {
                new ScoreCard(scoreCard).animate();
            }
        }
    });

    // Flash sync indicator
    const syncDot = document.querySelector('.sync-dot');
    if (syncDot) {
        syncDot.style.animation = 'pulseRing 1s cubic-bezier(0.4, 0, 0.6, 1) 3';
    }
}

// Make simulateLiveUpdate available globally for testing
if (typeof window !== 'undefined') {
    window.simulateLiveUpdate = simulateLiveUpdate;
}
