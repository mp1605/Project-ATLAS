// API Base URL
const API_URL = '/api/v1';

// Get token
function getToken() {
    return localStorage.getItem('auth_token');
}

// Get soldier ID from URL
function getSoldierId() {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('id');
}

// Load soldier detail
async function loadSoldierDetail() {
    const soldierId = getSoldierId();
    if (!soldierId) {
        alert('No soldier ID provided');
        window.location.href = 'Dashboard.html';
        return;
    }

    try {
        const token = getToken();
        if (!token) {
            window.location.href = 'login.html';
            return;
        }

        const response = await fetch(`${API_URL}/soldiers/${soldierId}`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) {
            throw new Error('Failed to fetch soldier');
        }

        const soldier = await response.json();
        updateSoldierUI(soldier);
    } catch (error) {
        console.error('Error loading soldier:', error);
        if (error.message.includes('401') || error.message.includes('403')) {
            window.location.href = 'login.html';
        }
    }
}

// Update soldier detail UI
function updateSoldierUI(soldier) {
    // Update name and rank
    const nameEl = document.querySelector('.bio-name');
    const rankEl = document.querySelector('.bio-rank');

    if (nameEl) nameEl.textContent = soldier.name;
    if (rankEl) rankEl.textContent = soldier.rank;

    // Update avatar
    const avatarEl = document.querySelector('.bio-avatar-large');
    if (avatarEl && soldier.avatar_url) {
        avatarEl.src = soldier.avatar_url;
    }

    // Update stats
    const statsEls = document.querySelectorAll('.bio-stat');
    if (statsEls.length >= 4) {
        statsEls[0].innerHTML = `<strong>Unit</strong>${soldier.unit || 'N/A'}`;
        statsEls[1].innerHTML = `<strong>Status</strong>${soldier.status}`;
        statsEls[2].innerHTML = `<strong>Last Assessed</strong>${formatDate(soldier.last_assessment)}`;
        statsEls[3].innerHTML = `<strong>Service Time</strong>5 years`; // Could be calculated from DB
    }

    // Update metric boxes
    updateMetricBox('readiness', soldier.readiness_score, soldier.readiness_score >= 70 ? 'Normal' : 'Needs Attention');
    updateMetricBox('training', soldier.training_completion, soldier.training_completion >= 70 ? 'On Track' : 'Behind');
    updateMetricBox('heart-rate', soldier.heart_rate, 'Healthy');
}

// Update metric box
function updateMetricBox(type, value, status) {
    const metricBox = document.querySelector(`.metric-${type}`);
    if (!metricBox) return;

    const valueEl = metricBox.querySelector('.metric-value-big');
    const statusEl = metricBox.querySelector('.metric-status');

    if (valueEl) {
        if (type === 'heart-rate') {
            valueEl.innerHTML = `${value}<span class="metric-unit">bpm</span>`;
        } else {
            valueEl.innerHTML = `${value}<span class="metric-unit">%</span>`;
        }
    }

    if (statusEl) {
        statusEl.textContent = status;
    }
}

// Format date
function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}

// Make metrics editable
function enableMetricEditing() {
    const metricValues = document.querySelectorAll('.metric-value-big');

    metricValues.forEach(el => {
        el.style.cursor = 'pointer';
        el.title = 'Click to edit';

        el.addEventListener('click', async function () {
            const currentValue = parseInt(this.textContent);
            const newValue = prompt('Enter new value:', currentValue);

            if (newValue !== null && !isNaN(newValue)) {
                const soldierId = getSoldierId();
                const metricType = this.closest('[class*="metric-"]').className.match(/metric-(\w+)/)[1];

                try {
                    await updateSoldierMetric(soldierId, metricType, parseInt(newValue));
                    this.textContent = newValue;
                    if (this.querySelector('.metric-unit')) {
                        this.innerHTML = `${newValue}${this.querySelector('.metric-unit').outerHTML}`;
                    }
                } catch (error) {
                    alert('Failed to update metric');
                }
            }
        });
    });
}

// Update soldier metric
async function updateSoldierMetric(soldierId, metricType, value) {
    const token = getToken();

    const fieldMap = {
        'readiness': 'readiness_score',
        'training': 'training_completion',
        'heart-rate': 'heart_rate'
    };

    const updateData = {};
    updateData[fieldMap[metricType]] = value;

    const response = await fetch(`${API_URL}/soldiers/${soldierId}`, {
        method: 'PUT',
        headers: {
            'Authorization': `Bearer ${token}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(updateData)
    });

    if (!response.ok) {
        throw new Error('Failed to update metric');
    }

    return response.json();
}

// Initialize soldier detail page
if (window.location.pathname.includes('soldier_detail.html')) {
    document.addEventListener('DOMContentLoaded', () => {
        loadSoldierDetail();
        setTimeout(enableMetricEditing, 1000); // Enable editing after data loads
    });
}
