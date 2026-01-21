// Uses window.API_URL from auth.js
const API_URL = window.API_URL || '/api/v1';

// Get token
function getToken() {
    return localStorage.getItem('auth_token');
}

// Fetch users with readiness data
async function loadDashboardData() {
    try {
        const token = getToken();
        if (!token) {
            window.location.href = 'login.html';
            return;
        }

        // Fetch user readiness summaries
        const response = await fetch(`${API_URL}/readiness/users`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) {
            if (response.status === 401 || response.status === 403) {
                window.location.href = 'login.html';
                return;
            }
            throw new Error('Failed to fetch dashboard data');
        }

        const data = await response.json();
        const users = data.users || [];

        // Update UI
        updateDashboardUI(users);
    } catch (error) {
        console.error('Error loading dashboard:', error);
    }
}

// Update dashboard UI with data
function updateDashboardUI(users) {
    if (users.length === 0) return;

    // Calculate summary stats from users
    const totalPersonnel = users.length;
    let totalReadiness = 0;
    let readyCount = 0;
    let atRiskCount = 0;
    let notReadyCount = 0;

    users.forEach(user => {
        const score = user.latest_score || 0;
        totalReadiness += score;

        if (score >= 70) readyCount++;
        else if (score >= 40) atRiskCount++;
        else notReadyCount++;
    });

    const avgReadiness = Math.round(totalReadiness / totalPersonnel);

    // Update readiness gauge
    const gaugeValue = document.querySelector('.gauge-value');
    if (gaugeValue) {
        gaugeValue.textContent = avgReadiness;
    }

    // Update Quick Stats
    const totalPersonnelEl = document.getElementById('totalPersonnel');
    if (totalPersonnelEl) totalPersonnelEl.textContent = totalPersonnel;

    const readyDeploymentEl = document.getElementById('readyDeployment');
    if (readyDeploymentEl) readyDeploymentEl.textContent = readyCount;

    // Update soldier list
    const soldierList = document.querySelector('.mini-soldier-list') || document.querySelector('.at-risk-list');
    if (soldierList) {
        soldierList.innerHTML = users.map(user => `
            <a href="soldier_detail.html?email=${user.user_id}" class="at-risk-item ${getScoreClass(user.latest_score === 0 ? 0 : user.latest_score)}" style="text-decoration: none; color: inherit; display: flex; width: 100%;">
                <div class="at-risk-info">
                    <div class="at-risk-name">${user.user_id.split('@')[0].toUpperCase()}</div>
                    <div class="at-risk-reason">Latest assessment: ${calculateTimeAgo(user.latest_submission)}</div>
                </div>
                <div class="at-risk-badge badge-${getScoreClass(user.latest_score)}">${user.latest_score || 'N/A'}</div>
            </a>
        `).join('');
    }

    // Update Status Bars
    const readyPercent = Math.round((readyCount / totalPersonnel) * 100);
    const atRiskPercent = Math.round((atRiskCount / totalPersonnel) * 100);
    const notReadyPercent = Math.round((notReadyCount / totalPersonnel) * 100);

    updateStatusBar('Ready', readyPercent, readyCount);
    updateStatusBar('At Risk', atRiskPercent, atRiskCount);
    updateStatusBar('Not Ready', notReadyPercent, notReadyCount);
}

function updateStatusBar(label, percent, count) {
    const bars = document.querySelectorAll('.status-bar-item');
    bars.forEach(bar => {
        if (bar.querySelector('.status-bar-label span:nth-child(2)').textContent === label) {
            bar.querySelector('.status-count').textContent = count;
            bar.querySelector('.status-bar-fill').style.width = `${percent}%`;
            bar.querySelector('.status-percent').textContent = `${percent}%`;
        }
    });
}

// Get score class based on value
function getScoreClass(score) {
    if (score >= 70) return 'green';
    if (score >= 40) return 'orange';
    return 'red';
}

// Get score class (green, orange, red) based on value
function getScoreClass(score) {
    if (score >= 70) return 'green';
    if (score >= 40) return 'orange';
    return 'red';
}

// Calculate time ago from date
function calculateTimeAgo(date) {
    if (!date) return 'N/A';
    const now = new Date();
    const past = new Date(date);
    const diffTime = Math.abs(now - past);
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

    if (diffDays < 30) return `${diffDays} days ago`;
    const diffMonths = Math.floor(diffDays / 30);
    return `${diffMonths} mon ago`;
}

// Update donut legend
function updateDonutLegend(ready, atRisk, notReady) {
    const legends = document.querySelectorAll('.donut-legend div');
    if (legends.length >= 3) {
        const readyEl = legends[0].querySelector('.l-green');
        const atRiskEl = legends[1].querySelector('.l-orange');
        const notReadyEl = legends[2].querySelector('.l-red');

        if (readyEl) readyEl.textContent = `Ready (${ready}%)`;
        if (atRiskEl) atRiskEl.textContent = `At Risk (${atRisk}%)`;
        if (notReadyEl) notReadyEl.textContent = `Not Ready (${notReady}%)`;
    }
}

// Initialize dashboard when page loads
if (document.querySelector('.main-board')) {
    document.addEventListener('DOMContentLoaded', () => {
        loadDashboardData();

        // Refresh data every 30 seconds
        setInterval(loadDashboardData, 30000);
    });
}
