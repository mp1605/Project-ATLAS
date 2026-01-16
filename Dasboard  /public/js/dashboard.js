// API Base URL
const API_URL = 'http://localhost:3000/api';

// Get token
function getToken() {
    return localStorage.getItem('auth_token');
}

// Fetch soldiers and update dashboard
async function loadDashboardData() {
    try {
        const token = getToken();
        if (!token) {
            window.location.href = 'login.html';
            return;
        }

        // Fetch soldiers
        const soldiersResponse = await fetch(`${API_URL}/soldiers`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!soldiersResponse.ok) {
            throw new Error('Failed to fetch soldiers');
        }

        const soldiers = await soldiersResponse.json();

        // Fetch dashboard summary
        const summaryResponse = await fetch(`${API_URL}/metrics/summary`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        const summary = await summaryResponse.json();

        // Update UI
        updateDashboardUI(soldiers, summary);
    } catch (error) {
        console.error('Error loading dashboard:', error);
        if (error.message.includes('401') || error.message.includes('403')) {
            window.location.href = 'login.html';
        }
    }
}

// Update dashboard UI with data
function updateDashboardUI(soldiers, summary) {
    // Update readiness gauge
    const gaugeValue = document.querySelector('.gauge-value');
    if (gaugeValue) {
        gaugeValue.textContent = summary.avg_readiness || 62;
    }

    // Update soldier list
    const soldierList = document.querySelector('.mini-soldier-list');
    if (soldierList && soldiers.length > 0) {
        soldierList.innerHTML = soldiers.slice(0, 4).map(soldier => `
      <a href="soldier_detail.html?id=${soldier.id}" class="soldier-row-text">
        <div class="s-name">${soldier.name}</div>
        <div class="s-info">
          <span class="score-${getScoreClass(soldier.readiness_score)}">${soldier.readiness_score}</span>
          • ${calculateTimeAgo(soldier.last_assessment)}
        </div>
      </a>
    `).join('') + '<a href="#" class="show-more">Show more ></a>';
    }

    // Store soldiers for filtering
    if (typeof storeAllSoldiers === 'function') {
        storeAllSoldiers(soldiers);
    }

    // Update deployment readiness percentages
    const total = summary.distribution.ready + summary.distribution.at_risk + summary.distribution.not_ready;
    if (total > 0) {
        const readyPercent = Math.round((summary.distribution.ready / total) * 100);
        const atRiskPercent = Math.round((summary.distribution.at_risk / total) * 100);
        const notReadyPercent = Math.round((summary.distribution.not_ready / total) * 100);

        // Update donut chart legend
        updateDonutLegend(readyPercent, atRiskPercent, notReadyPercent);
    }

    // Update training completion
    const avgTrainingEl = document.querySelector('.progress-fill.fill-green');
    if (avgTrainingEl) {
        avgTrainingEl.style.width = `${summary.avg_training}%`;
        const trainingText = avgTrainingEl.closest('.progress-section')?.querySelector('h4 span');
        if (trainingText) {
            trainingText.textContent = `${summary.avg_training}%`;
        }
    }
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
