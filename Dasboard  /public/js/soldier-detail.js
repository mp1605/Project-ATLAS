// Soldier Detail View - JavaScript for Charts & Interactions

// Tab Switching
function switchDetailTab(tabName, element) {
    try {
        console.log('Switching to tab:', tabName);

        // Hide all tabs
        document.querySelectorAll('.detail-tab-content').forEach(tab => {
            tab.classList.remove('active');
        });

        // Show selected tab
        const selectedTab = document.getElementById(tabName + '-tab');
        if (selectedTab) {
            selectedTab.classList.add('active');
        } else {
            console.error('Missing tab content:', tabName + '-tab');
        }

        // Update button states
        document.querySelectorAll('.detail-tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });

        // Set active state on the button/link
        if (element) {
            element.classList.add('active');
        } else if (window.event && window.event.currentTarget) {
            window.event.currentTarget.classList.add('active');
        } else if (window.event && window.event.target) {
            const btn = window.event.target.closest('.detail-tab-btn');
            if (btn) btn.classList.add('active');
        }
    } catch (err) {
        console.error('Error in switchDetailTab:', err);
    }
}

// Score Explainer Drawer
function openScoreExplainer() {
    document.getElementById('scoreDrawer').classList.add('open');
}

function closeScoreExplainer() {
    document.getElementById('scoreDrawer').classList.remove('open');
}

// Parameter Profile Switching
function changeParameterProfile(profile) {
    const profiles = {
        training: { sleep: 25, hrv: 25, fatigue: 30, recovery: 20 },
        deployment: { sleep: 30, hrv: 30, fatigue: 25, recovery: 15 },
        recovery: { sleep: 35, hrv: 20, fatigue: 15, recovery: 30 }
    };

    const profileNames = {
        training: 'Training Mode',
        deployment: 'Deployment Mode',
        recovery: 'Recovery Mode'
    };

    document.getElementById('currentProfileName').textContent = profileNames[profile];

    // Recalculate readiness with new weights (placeholder - would connect to actual calculation)
    console.log('Switched to ' + profile + ' profile');
}

// Toggle functions
function toggleReadinessTrend(days) {
    document.querySelectorAll('.toggle-btn').forEach(btn => btn.classList.remove('active'));
    event.target.classList.add('active');
    // Update chart with new data (placeholder)
    console.log(`Showing ${days} days of readiness data`);
}

function toggleSleepPeriod(days) {
    document.querySelectorAll('.toggle-btn').forEach(btn => btn.classList.remove('active'));
    event.target.classList.add('active');
    console.log(`Showing ${days} days of sleep data`);
}

// Initialize all charts on page load
document.addEventListener('DOMContentLoaded', function () {
    const urlParams = new URLSearchParams(window.location.search);
    const userEmail = urlParams.get('email') || 'soldier_1@example.com';

    loadSoldierData(userEmail);
    initOverviewCharts();
    initTrendsCharts();
    initSleepCharts();
    initPhysiologyCharts();
    initActivityCharts();
});

// Fetch Soldier Data from Backend
async function loadSoldierData(userEmail) {
    try {
        const token = localStorage.getItem('auth_token');
        if (!token) {
            window.location.href = 'login.html';
            return;
        }

        // Fetch latest readiness
        const baseUrl = window.API_URL || 'http://localhost:3000/api/v1';
        const response = await fetch(`${baseUrl}/readiness/${userEmail}/latest`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) throw new Error('Failed to fetch soldier data');

        const data = await response.json();
        update18ScoreGrid(data.scores);

        // Update header info dynamically from database
        const nameEl = document.querySelector('.profile-details-integrated h1');
        if (nameEl && data.name) nameEl.textContent = data.name;

        const metaEl = document.querySelector('.profile-meta-integrated');
        if (metaEl && data.rank) {
            metaEl.innerHTML = `
                <span class="meta-item">ID: ${data.id || '---'}</span>
                <span class="meta-divider">•</span>
                <span class="meta-item">${data.rank}</span>
                <span class="meta-divider">•</span>
                <span class="meta-item">Personnel</span>
                <span class="meta-divider">•</span>
                <span class="meta-item">${data.unit || 'AUIX Unit'}</span>
            `;
        }

        // Update sync time
        const syncText = document.querySelector('.sync-text-compact');
        if (syncText && data.timestamp) {
            const lastSync = new Date(data.timestamp);
            const now = new Date();
            const diffMin = Math.floor((now - lastSync) / 60000);
            syncText.textContent = diffMin < 60 ? `Last sync: ${diffMin}m ago` : `Last sync: ${Math.floor(diffMin / 60)}h ago`;
        }

    } catch (error) {
        console.error('Error loading soldier data:', error);
    }
}

// Helper: Fetch historical data for a specific metric
async function fetchHistoricalData(userEmail, type, days = 7) {
    try {
        const token = localStorage.getItem('auth_token');
        const baseUrl = window.API_URL || 'http://localhost:3000/api/v1';
        const response = await fetch(`${baseUrl}/readiness/${userEmail}/history?type=${type}&days=${days}`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        if (!response.ok) return [];
        const result = await response.json();
        return result.data || [];
    } catch (e) {
        console.error(`Error fetching history for ${type}:`, e);
        return [];
    }
}

// Update the 18 Score Grid
function update18ScoreGrid(scores) {
    if (!scores) return;

    console.log('Syncing 18 scores to UI cards...');

    // Comprehensive mapping of all 18 readiness metrics
    // Maps legacy or alternative keys to the standardized HTML IDs
    const keyMap = {
        // Core Readiness (1-6)
        'readiness': 'readiness',
        'readiness_score': 'readiness',
        'recovery': 'recovery',
        'recovery_score': 'recovery',
        'sleep_quality': 'sleep_quality',
        'sleep': 'sleep_quality',
        'sleep_index': 'sleep_quality',
        'fatigue_index': 'fatigue_index',
        'fatigue': 'fatigue_index',
        'training_load': 'training_load',      // Endurance
        'endurance': 'training_load',
        'cardiovascular_strain': 'cardiovascular_strain', // Cardio Fitness
        'cardio': 'cardiovascular_strain',

        // Safety & Load (7-12)
        'stress_load': 'stress_load',
        'stress': 'stress_load',
        'overtraining_risk': 'overtraining_risk', // Injury Risk
        'injury': 'overtraining_risk',
        'autonomic_balance': 'autonomic_balance', // Cardio Stability
        'cardio_resp': 'autonomic_balance',
        'illness_risk': 'illness_risk',
        'illness': 'illness_risk',
        'physical_status': 'physical_status',    // Daily Activity
        'activity': 'physical_status',
        'energy_availability': 'energy_availability', // Work Capacity
        'capacity': 'energy_availability',

        // Specialty Metrics (13-18)
        'oxygen_stability': 'oxygen_stability',   // Altitude Score
        'altitude': 'oxygen_stability',
        'hrv_deviation': 'hrv_deviation',         // Cardiac Safety
        'cardiac_safety': 'hrv_deviation',
        'sleep_debt': 'sleep_debt',
        'debt': 'sleep_debt',
        'resting_hr_deviation': 'resting_hr_deviation', // Training Readiness
        'training_readiness': 'resting_hr_deviation',
        'respiratory_stability': 'respiratory_stability', // Cognitive Alert
        'cognitive_alertness': 'respiratory_stability',
        'acute_chronic_ratio': 'acute_chronic_ratio',  // Thermoregulatory
        'thermo': 'acute_chronic_ratio'
    };

    // First, normalize the scores map using the keyMap
    const normalizedData = {};
    Object.entries(scores).forEach(([key, value]) => {
        const standardKey = keyMap[key] || key;
        normalizedData[standardKey] = value;
    });

    // Handle special case: the database sometimes stores 'readiness' but the card ID is 'card-readiness'
    // This loop covers all 18 possible cards
    const allExpectedKeys = [
        'readiness', 'recovery', 'sleep_quality', 'fatigue_index', 'training_load', 'cardiovascular_strain',
        'stress_load', 'overtraining_risk', 'autonomic_balance', 'illness_risk', 'physical_status', 'energy_availability',
        'oxygen_stability', 'hrv_deviation', 'sleep_debt', 'resting_hr_deviation', 'respiratory_stability', 'acute_chronic_ratio'
    ];

    allExpectedKeys.forEach(key => {
        const card = document.getElementById(`card-${key}`);
        if (card) {
            const value = normalizedData[key];
            const valueEl = card.querySelector('.score-value');
            const statusEl = card.querySelector('.score-status');

            if (value !== undefined && value !== null) {
                const numericValue = parseFloat(value);
                valueEl.textContent = numericValue.toFixed(1);

                // Apply Status Class
                let status = 'go';
                if (numericValue < 40) status = 'stop';
                else if (numericValue < 60) status = 'limited';
                else if (numericValue < 75) status = 'caution';

                statusEl.textContent = status.toUpperCase();
                statusEl.className = `score-status status-${status}`;
            } else {
                // If no data, keep it as Pending
                valueEl.textContent = '--';
                statusEl.textContent = 'PENDING';
                statusEl.className = 'score-status';
            }
        }
    });
}

// ===== OVERVIEW TAB CHARTS =====
function initOverviewCharts() {
    // Legacy support for sparklines if needed
}

// ===== TRENDS TAB CHARTS =====
async function initTrendsCharts() {
    const urlParams = new URLSearchParams(window.location.search);
    const userEmail = urlParams.get('email') || 'soldier_1@example.com';

    // Fetch real readiness trend data
    const trendData = await fetchHistoricalData(userEmail, 'readiness', 30);
    const labels = trendData.length > 0 ? trendData.map(d => new Date(d.recorded_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })) : Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`);
    const values = trendData.length > 0 ? trendData.map(d => d.value) : Array(30).fill(0);

    // Calculate moving average
    const calculateMA = (data, p) => {
        return data.map((val, i) => {
            if (i < p - 1) return null;
            const sub = data.slice(i - p + 1, i + 1);
            return sub.reduce((a, b) => a + b) / p;
        });
    };
    const maValues = trendData.length >= 7 ? calculateMA(values, 7) : Array(values.length).fill(null);

    // Main Readiness Trend
    const readinessTrendCtx = document.getElementById('readinessTrendChart');
    if (readinessTrendCtx) {
        new Chart(readinessTrendCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Daily Readiness',
                        data: values,
                        borderColor: '#3b82f6',
                        backgroundColor: 'rgba(59, 130, 246, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4,
                        pointRadius: 3,
                        pointHoverRadius: 6
                    },
                    {
                        label: '7-day Moving Average',
                        data: maValues,
                        borderColor: '#f59e0b',
                        borderWidth: 2,
                        borderDash: [5, 5],
                        fill: false,
                        tension: 0.4,
                        pointRadius: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#9ca3af' }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        min: 0,
                        max: 100,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { color: 'rgba(255, 255, 255, 0.05)' },
                        ticks: {
                            color: '#9ca3af',
                            maxTicksLimit: 10
                        }
                    }
                }
            }
        });
    }

    // Mini charts helper
    const initMiniChart = async (canvasId, metricType, color) => {
        const ctx = document.getElementById(canvasId);
        if (!ctx) return;

        const data = await fetchHistoricalData(userEmail, metricType, 30);
        const vals = data.length > 0 ? data.map(d => d.value) : Array(30).fill(0);

        new Chart(ctx, {
            type: 'line',
            data: {
                labels: Array.from({ length: vals.length }, (_, i) => i),
                datasets: [{
                    data: vals,
                    borderColor: color,
                    backgroundColor: `${color}33`,
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    x: { display: false },
                    y: { display: false }
                }
            }
        });
    };

    // 4 Mini Trend Charts
    await initMiniChart('sleepMiniChart', 'sleep_hours', '#8b5cf6');
    await initMiniChart('hrvMiniChart', 'hrv_deviation', '#10b981');
    await initMiniChart('fatigueMiniChart', 'fatigue_index', '#ef4444');
    await initMiniChart('recoveryMiniChart', 'recovery', '#06b6d4');

    // Distribution Chart (Keep static for now or fetch if needed)
    const distributionCtx = document.getElementById('distributionChart');
    if (distributionCtx) {
        new Chart(distributionCtx, {
            type: 'doughnut',
            data: {
                labels: ['Fit Days', 'Monitor Days', 'Risk Days'],
                datasets: [{
                    data: [18, 8, 4],
                    backgroundColor: ['#10b981', '#f59e0b', '#ef4444'],
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom',
                        labels: { color: '#9ca3af', padding: 15 }
                    }
                }
            }
        });
    }
}

// ===== SLEEP & RECOVERY TAB CHARTS =====
async function initSleepCharts() {
    const urlParams = new URLSearchParams(window.location.search);
    const userEmail = urlParams.get('email') || 'soldier_1@example.com';

    // Fetch real sleep duration data
    const sleepData = await fetchHistoricalData(userEmail, 'sleep_hours', 7);
    const labels = sleepData.length > 0 ? sleepData.map(d => new Date(d.recorded_at).toLocaleDateString('en-US', { weekday: 'short' })) : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const values = sleepData.length > 0 ? sleepData.map(d => d.value) : [0, 0, 0, 0, 0, 0, 0];

    // Sleep Hours Trend
    const sleepHoursCtx = document.getElementById('sleepHoursChart');
    if (sleepHoursCtx) {
        new Chart(sleepHoursCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Actual Sleep (hrs)',
                        data: values,
                        borderColor: '#8b5cf6',
                        backgroundColor: 'rgba(139, 92, 246, 0.2)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'Target (8 hrs)',
                        data: Array(labels.length).fill(8),
                        borderColor: '#10b981',
                        borderWidth: 2,
                        borderDash: [5, 5],
                        fill: false,
                        pointRadius: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#9ca3af' }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        min: 0,
                        max: 12,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { color: '#9ca3af' }
                    }
                }
            }
        });
    }

    // Fetch real sleep quality data
    const qualityData = await fetchHistoricalData(userEmail, 'sleep_quality', 7);
    const qLabels = qualityData.length > 0 ? qualityData.map(d => new Date(d.recorded_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })) : labels;
    const qValues = qualityData.length > 0 ? qualityData.map(d => d.value) : [0, 0, 0, 0, 0, 0, 0];

    // Sleep Quality
    const sleepQualityCtx = document.getElementById('sleepQualityChart');
    if (sleepQualityCtx) {
        new Chart(sleepQualityCtx, {
            type: 'line',
            data: {
                labels: qLabels,
                datasets: [{
                    label: 'Quality Score',
                    data: qValues,
                    borderColor: '#06b6d4',
                    backgroundColor: 'rgba(6, 182, 212, 0.2)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: {
                        beginAtZero: true,
                        min: 0,
                        max: 100,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { color: '#9ca3af' }
                    }
                }
            }
        });
    }

    // Sleep Debt Accumulation (Stacked Bar - inspired by reference)
    const sleepDebtCtx = document.getElementById('sleepDebtChart');
    if (sleepDebtCtx) {
        new Chart(sleepDebtCtx, {
            type: 'bar',
            data: {
                labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                datasets: [{
                    label: 'Daily Deficit',
                    data: [1.8, 2.2, 1.6, 1.9, 2.1, 1.7, 1.8],
                    backgroundColor: ['#fef08a', '#fef08a', '#fb923c', '#fb923c', '#ef4444', '#fb923c', '#fef08a']
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { color: '#9ca3af' }
                    }
                }
            }
        });
    }
}

// ===== PHYSIOLOGY TAB CHARTS =====
async function initPhysiologyCharts() {
    const urlParams = new URLSearchParams(window.location.search);
    const userEmail = urlParams.get('email') || 'soldier_1@example.com';

    // Resting HR
    const restingHrCtx = document.getElementById('restingHrChart');
    if (restingHrCtx) {
        const hrData = await fetchHistoricalData(userEmail, 'resting_hr_deviation', 30);
        const labels = hrData.length > 0 ? hrData.map(d => new Date(d.recorded_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })) : Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`);
        const values = hrData.length > 0 ? hrData.map(d => d.value) : Array(30).fill(60);

        new Chart(restingHrCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'Resting HR',
                        data: values,
                        borderColor: '#ef4444',
                        backgroundColor: 'rgba(239, 68, 68, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'Baseline (60 bpm)',
                        data: Array(labels.length).fill(60),
                        borderColor: '#6b7280',
                        borderWidth: 2,
                        borderDash: [5, 5],
                        fill: false,
                        pointRadius: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#9ca3af' }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: false,
                        min: 40,
                        max: 100,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: {
                            color: '#9ca3af',
                            maxTicksLimit: 10
                        }
                    }
                }
            }
        });
    }

    // HRV Chart
    const hrvCtx = document.getElementById('hrvChart');
    if (hrvCtx) {
        const hrvData = await fetchHistoricalData(userEmail, 'hrv_deviation', 30);
        const labels = hrvData.length > 0 ? hrvData.map(d => new Date(d.recorded_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })) : Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`);
        const values = hrvData.length > 0 ? hrvData.map(d => d.value) : Array(30).fill(65);

        new Chart(hrvCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'HRV',
                        data: values,
                        borderColor: '#10b981',
                        backgroundColor: 'rgba(16, 185, 129, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'Baseline (65 ms)',
                        data: Array(labels.length).fill(65),
                        borderColor: '#6b7280',
                        borderWidth: 2,
                        borderDash: [5, 5],
                        fill: false,
                        pointRadius: 0
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#9ca3af' }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: false,
                        min: 20,
                        max: 120,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: {
                            color: '#9ca3af',
                            maxTicksLimit: 10
                        }
                    }
                }
            }
        });
    }

    // Heart Rate Zones (Inspired by Reference)
    const hrZonesCtx = document.getElementById('hrZonesChart');
    if (hrZonesCtx) {
        new Chart(hrZonesCtx, {
            type: 'bar',
            data: {
                labels: ['6:00', '7:00', '8:00', '9:00', '10:00', '11:00', '12:00', '1:00', '2:00', '3:00', '4:00', '5:00'],
                datasets: [
                    {
                        label: 'Light',
                        data: [45, 50, 30, 20, 35, 40, 45, 50, 40, 35, 30, 25],
                        backgroundColor: '#475569',
                        stack: 'stack1'
                    },
                    {
                        label: 'Intensive',
                        data: [20, 25, 15, 10, 20, 25, 20, 15, 20, 25, 20, 15],
                        backgroundColor: '#fef08a',
                        stack: 'stack1'
                    },
                    {
                        label: 'Aerobic',
                        data: [10, 15, 25, 30, 15, 10, 15, 20, 15, 10, 15, 20],
                        backgroundColor: '#06b6d4',
                        stack: 'stack1'
                    },
                    {
                        label: 'Anaerobic',
                        data: [5, 10, 15, 20, 10, 5, 10, 15, 5, 10, 15, 10],
                        backgroundColor: '#0891b2',
                        stack: 'stack1'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false }
                },
                scales: {
                    y: {
                        stacked: true,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        stacked: true,
                        grid: { display: false },
                        ticks: { color: '#9ca3af' }
                    }
                }
            }
        });
    }
}

// ===== ACTIVITY TAB CHARTS =====
async function initActivityCharts() {
    const urlParams = new URLSearchParams(window.location.search);
    const userEmail = urlParams.get('email') || 'soldier_1@example.com';

    // Steps Chart
    const stepsCtx = document.getElementById('stepsChart');
    if (stepsCtx) {
        const stepsData = await fetchHistoricalData(userEmail, 'physical_status', 30);
        const labels = stepsData.length > 0 ? stepsData.map(d => new Date(d.recorded_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' })) : Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`);
        // Scale physical_status (0-100) to typical step counts for visualization if needed, or just show the index
        const values = stepsData.length > 0 ? stepsData.map(d => d.value) : Array(30).fill(0);

        new Chart(stepsCtx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Activity Index',
                    data: values,
                    borderColor: '#f59e0b',
                    backgroundColor: 'rgba(245, 158, 11, 0.2)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: {
                        beginAtZero: true,
                        min: 0,
                        max: 100,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: {
                            color: '#9ca3af',
                            maxTicksLimit: 10
                        }
                    }
                }
            }
        });
    }

    // Active Energy
    const activeEnergyCtx = document.getElementById('activeEnergyChart');
    if (activeEnergyCtx) {
        new Chart(activeEnergyCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`),
                datasets: [{
                    label: 'Calories',
                    data: [420, 480, 390, 410, 520, 570, 460, 440, 490, 430, 400, 450, 500, 540, 590, 560, 510, 470, 430, 490, 530, 460, 420, 480, 540, 580, 550, 500, 460, 510],
                    borderColor: '#8b5cf6',
                    backgroundColor: 'rgba(139, 92, 246, 0.2)',
                    borderWidth: 3,
                    fill: true,
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: {
                        beginAtZero: false,
                        min: 350,
                        max: 650,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: {
                            color: '#9ca3af',
                            maxTicksLimit: 10
                        }
                    }
                }
            }
        });
    }

    // Load vs Recovery
    const loadRecoveryCtx = document.getElementById('loadRecoveryChart');
    if (loadRecoveryCtx) {
        new Chart(loadRecoveryCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 14 }, (_, i) => `Day ${i + 1}`),
                datasets: [
                    {
                        label: 'Training Load',
                        data: [50, 55, 60, 65, 70, 75, 72, 68, 65, 70, 75, 80, 78, 75],
                        borderColor: '#ef4444',
                        backgroundColor: 'rgba(239, 68, 68, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4,
                        yAxisID: 'y'
                    },
                    {
                        label: 'Recovery Score',
                        data: [85, 82, 80, 78, 75, 72, 75, 78, 80, 78, 75, 70, 73, 76],
                        borderColor: '#10b981',
                        backgroundColor: 'rgba(16, 185, 129, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4,
                        yAxisID: 'y'
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                        labels: { color: '#9ca3af' }
                    }
                },
                scales: {
                    y: {
                        type: 'linear',
                        display: true,
                        position: 'left',
                        min: 0,
                        max: 100,
                        grid: { color: 'rgba(255, 255, 255, 0.1)' },
                        ticks: { color: '#9ca3af' }
                    },
                    x: {
                        grid: { display: false },
                        ticks: { color: '#9ca3af' }
                    }
                }
            }
        });
    }
}
