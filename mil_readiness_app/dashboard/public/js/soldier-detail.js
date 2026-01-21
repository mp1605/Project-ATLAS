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
        const baseUrl = window.API_URL || '/api/v1';
        const response = await fetch(`${baseUrl}/readiness/${userEmail}/latest`, {
            headers: {
                'Authorization': `Bearer ${token}`
            }
        });

        if (!response.ok) throw new Error('Failed to fetch soldier data');

        const data = await response.json();
        update18ScoreGrid(data.scores);

        // Update header info
        const nameEl = document.querySelector('.soldier-name h1');
        if (nameEl) nameEl.textContent = userEmail.split('@')[0].toUpperCase();

    } catch (error) {
        console.error('Error loading soldier data:', error);
    }
}

// Update the 18 Score Grid
function update18ScoreGrid(scores) {
    if (!scores) return;

    for (const [key, value] of Object.entries(scores)) {
        const card = document.getElementById(`card-${key}`);
        if (card) {
            const valueEl = card.querySelector('.score-value');
            const statusEl = card.querySelector('.score-status');

            const numericValue = parseFloat(value);
            valueEl.textContent = numericValue.toFixed(1);

            // Apply Status Class
            let status = 'go';
            if (numericValue < 40) status = 'stop';
            else if (numericValue < 60) status = 'limited';
            else if (numericValue < 75) status = 'caution';

            statusEl.textContent = status.toUpperCase();
            statusEl.className = `score-status status-${status}`;
        }
    }
}

// ===== OVERVIEW TAB CHARTS =====
function initOverviewCharts() {
    // Legacy support for sparklines if needed
}

// ===== TRENDS TAB CHARTS =====
function initTrendsCharts() {
    // Main Readiness Trend
    const readinessTrendCtx = document.getElementById('readinessTrendChart');
    if (readinessTrendCtx) {
        new Chart(readinessTrendCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`),
                datasets: [
                    {
                        label: 'Daily Readiness',
                        data: [68, 72, 71, 75, 78, 76, 74, 72, 70, 68, 65, 70, 73, 75, 78, 80, 82, 81, 79, 77, 75, 73, 70, 68, 65, 67, 69, 70, 68, 67],
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
                        data: [null, null, null, 72, 73, 74, 74, 73, 72, 70, 68, 69, 71, 73, 75, 77, 79, 80, 79, 78, 76, 74, 72, 70, 68, 68, 68, 68, 68, 68],
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
                        beginAtZero: false,
                        min: 50,
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

    // 4 Mini Trend Charts
    const miniChartOptions = {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
            x: { display: false },
            y: { display: false }
        }
    };

    // Sleep Mini
    const sleepMiniCtx = document.getElementById('sleepMiniChart');
    if (sleepMiniCtx) {
        new Chart(sleepMiniCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => i),
                datasets: [{
                    data: [7.2, 6.8, 7.0, 6.5, 6.2, 5.8, 6.1, 6.4, 6.7, 6.3, 5.9, 6.2, 6.5, 6.8, 7.1, 7.4, 7.2, 6.9, 6.5, 6.2, 5.8, 6.0, 6.3, 6.6, 6.4, 6.1, 5.9, 6.2, 6.3, 6.2],
                    borderColor: '#8b5cf6',
                    backgroundColor: 'rgba(139, 92, 246, 0.2)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0
                }]
            },
            options: miniChartOptions
        });
    }

    // HRV Mini
    const hrvMiniCtx = document.getElementById('hrvMiniChart');
    if (hrvMiniCtx) {
        new Chart(hrvMiniCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => i),
                datasets: [{
                    data: [65, 64, 63, 62, 61, 60, 59, 58, 57, 58, 59, 60, 61, 62, 63, 64, 63, 62, 61, 60, 59, 58, 57, 56, 57, 58, 59, 58, 57, 58],
                    borderColor: '#10b981',
                    backgroundColor: 'rgba(16, 185, 129, 0.2)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0
                }]
            },
            options: miniChartOptions
        });
    }

    // Fatigue Mini
    const fatigueMiniCtx = document.getElementById('fatigueMiniChart');
    if (fatigueMiniCtx) {
        new Chart(fatigueMiniCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => i),
                datasets: [{
                    data: [30, 32, 35, 38, 40, 42, 44, 45, 46, 44, 42, 40, 38, 36, 34, 32, 34, 36, 38, 40, 42, 44, 45, 46, 47, 46, 45, 44, 45, 45],
                    borderColor: '#ef4444',
                    backgroundColor: 'rgba(239, 68, 68, 0.2)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0
                }]
            },
            options: miniChartOptions
        });
    }

    // Recovery Mini
    const recoveryMiniCtx = document.getElementById('recoveryMiniChart');
    if (recoveryMiniCtx) {
        new Chart(recoveryMiniCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => i),
                datasets: [{
                    data: [75, 76, 78, 80, 82, 84, 83, 81, 79, 77, 75, 73, 75, 77, 79, 81, 83, 85, 84, 82, 80, 78, 76, 78, 80, 82, 84, 83, 82, 82],
                    borderColor: '#06b6d4',
                    backgroundColor: 'rgba(6, 182, 212, 0.2)',
                    borderWidth: 2,
                    fill: true,
                    tension: 0.4,
                    pointRadius: 0
                }]
            },
            options: miniChartOptions
        });
    }

    // Distribution Chart
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
function initSleepCharts() {
    // Sleep Hours Trend
    const sleepHoursCtx = document.getElementById('sleepHoursChart');
    if (sleepHoursCtx) {
        new Chart(sleepHoursCtx, {
            type: 'line',
            data: {
                labels: ['Day 1', 'Day 2', 'Day 3', 'Day 4', 'Day 5', 'Day 6', 'Day 7'],
                datasets: [
                    {
                        label: 'Actual Sleep',
                        data: [6.2, 5.8, 6.4, 6.1, 5.9, 6.3, 6.2],
                        borderColor: '#8b5cf6',
                        backgroundColor: 'rgba(139, 92, 246, 0.2)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'Target (8 hrs)',
                        data: [8, 8, 8, 8, 8, 8, 8],
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
                        beginAtZero: false,
                        min: 0,
                        max: 10,
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

    // Sleep Quality
    const sleepQualityCtx = document.getElementById('sleepQualityChart');
    if (sleepQualityCtx) {
        new Chart(sleepQualityCtx, {
            type: 'line',
            data: {
                labels: ['Day 1', 'Day 3', 'Day 5', 'Day 7', 'Day 10', 'Day 14'],
                datasets: [{
                    label: 'Quality Score',
                    data: [78, 72, 75, 68, 70, 74],
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
                        beginAtZero: false,
                        min: 50,
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
function initPhysiologyCharts() {
    // Resting HR
    const restingHrCtx = document.getElementById('restingHrChart');
    if (restingHrCtx) {
        new Chart(restingHrCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`),
                datasets: [
                    {
                        label: 'Resting HR',
                        data: [55, 56, 57, 58, 59, 60, 61, 60, 59, 58, 57, 58, 59, 60, 61, 62, 61, 60, 59, 58, 59, 60, 61, 62, 61, 60, 59, 60, 61, 60],
                        borderColor: '#ef4444',
                        backgroundColor: 'rgba(239, 68, 68, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'Baseline (55 bpm)',
                        data: Array(30).fill(55),
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
                        min: 50,
                        max: 70,
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
        new Chart(hrvCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`),
                datasets: [
                    {
                        label: 'HRV',
                        data: [65, 64, 63, 62, 61, 60, 59, 58, 57, 58, 59, 60, 61, 62, 63, 64, 63, 62, 61, 60, 59, 58, 57, 56, 57, 58, 59, 58, 57, 58],
                        borderColor: '#10b981',
                        backgroundColor: 'rgba(16, 185, 129, 0.1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4
                    },
                    {
                        label: 'Baseline (65 ms)',
                        data: Array(30).fill(65),
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
                        min: 50,
                        max: 70,
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
function initActivityCharts() {
    // Weekly Load (Stacked - inspired by reference Steps chart)
    const weeklyLoadCtx = document.getElementById('weeklyLoadChart');
    if (weeklyLoadCtx) {
        new Chart(weeklyLoadCtx, {
            type: 'bar',
            data: {
                labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
                datasets: [
                    {
                        label: 'Light',
                        data: [120, 150, 100, 80, 130, 140, 110],
                        backgroundColor: '#fef08a'
                    },
                    {
                        label: 'Moderate',
                        data: [80, 100, 120, 90, 100, 110, 90],
                        backgroundColor: '#fb923c'
                    },
                    {
                        label: 'Intense',
                        data: [40, 30, 50, 60, 40, 30, 50],
                        backgroundColor: '#ef4444'
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

    // Steps Chart
    const stepsCtx = document.getElementById('stepsChart');
    if (stepsCtx) {
        new Chart(stepsCtx, {
            type: 'line',
            data: {
                labels: Array.from({ length: 30 }, (_, i) => `Day ${i + 1}`),
                datasets: [{
                    label: 'Daily Steps',
                    data: [8500, 9200, 7800, 8100, 9500, 10200, 8900, 8700, 9100, 8300, 7900, 8500, 9000, 9400, 10100, 9800, 9200, 8800, 8400, 9000, 9300, 8700, 8100, 8900, 9500, 10000, 9600, 9100, 8700, 9200],
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
                        beginAtZero: false,
                        min: 7000,
                        max: 11000,
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
