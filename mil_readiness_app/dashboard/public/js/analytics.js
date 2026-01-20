// Analytics Tab Switching
function switchTab(tabName) {
    // Hide all sections
    document.querySelectorAll('.analytics-section').forEach(section => {
        section.classList.remove('active');
    });

    // Show selected section
    document.getElementById(tabName + '-section').classList.add('active');

    // Update active tab button
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');
}

// Toggle timeframe for readiness trend
let currentTimeframe = 30;
function toggleTimeframe(days) {
    currentTimeframe = days;

    // Update button states
    document.querySelectorAll('.toggle-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    event.target.classList.add('active');

    // Update chart (in a real app, fetch new data)
    updateReadinessTrend(days);
}

function updateReadinessTrend(days) {
    const chart = Chart.getChart('readinessTrendChart');
    if (chart) {
        // In a real app, fetch data for the selected timeframe
        chart.data.labels = days === 30 ? get30DayLabels() : get90DayLabels();
        chart.data.datasets[0].data = days === 30 ? get30DayData() : get90DayData();
        chart.update();
    }
}

function get30DayLabels() {
    return ['Day 1', 'Day 5', 'Day 10', 'Day 15', 'Day 20', 'Day 25', 'Day 30'];
}

function get90DayLabels() {
    return ['Week 1', 'Week 3', 'Week 5', 'Week 7', 'Week 9', 'Week 11'];
}

function get30DayData() {
    return [68, 72, 71, 75, 78, 76, 74];
}

function get90DayData() {
    return [70, 74, 72, 76, 75, 73];
}

// Initialize all charts when page loads
document.addEventListener('DOMContentLoaded', function () {
    initializeOverviewCharts();
    initializeFactorCharts();
    initializeForecastCharts();
    initializeParameterCharts();
});

// === OVERVIEW CHARTS ===
function initializeOverviewCharts() {

    // Readiness Trend Chart
    new Chart(document.getElementById('readinessTrendChart'), {
        type: 'line',
        data: {
            labels: get30DayLabels(),
            datasets: [{
                label: 'Unit Readiness Score',
                data: get30DayData(),
                borderColor: '#3b82f6',
                backgroundColor: 'rgba(59, 130, 246, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 3
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    backgroundColor: 'rgba(17, 24, 39, 0.9)',
                    titleColor: '#fff',
                    bodyColor: '#fff'
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
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });

    // Distribution Chart (Stacked Bar)
    new Chart(document.getElementById('distributionChart'), {
        type: 'bar',
        data: {
            labels: ['Week 1', 'Week 2', 'Week 3', 'Week 4'],
            datasets: [
                {
                    label: 'Fit',
                    data: [120, 125, 128, 130],
                    backgroundColor: '#10b981'
                },
                {
                    label: 'Monitor',
                    data: [45, 42, 38, 35],
                    backgroundColor: '#f59e0b'
                },
                {
                    label: 'Risk',
                    data: [18, 16, 17, 18],
                    backgroundColor: '#ef4444'
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: { color: '#9ca3af', padding: 15 }
                }
            },
            scales: {
                x: {
                    stacked: true,
                    grid: { display: false },
                    ticks: { color: '#9ca3af' }
                },
                y: {
                    stacked: true,
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });

    // Fatigue Mini Chart
    new Chart(document.getElementById('fatigueChartMini'), {
        type: 'line',
        data: {
            labels: ['', '', '', '', '', ''],
            datasets: [{
                data: [45, 52, 58, 62, 68, 72],
                borderColor: '#f59e0b',
                backgroundColor: 'rgba(245, 158, 11, 0.2)',
                fill: true,
                tension: 0.4,
                borderWidth: 2,
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
}

// === FACTOR ANALYSIS CHARTS ===
function initializeFactorCharts() {

    // Sleep vs Readiness Scatter
    new Chart(document.getElementById('sleepScatterChart'), {
        type: 'scatter',
        data: {
            datasets: [{
                label: 'Soldiers',
                data: [
                    { x: 7.2, y: 85 }, { x: 6.5, y: 72 }, { x: 5.8, y: 58 },
                    { x: 7.8, y: 92 }, { x: 6.1, y: 65 }, { x: 7.5, y: 88 },
                    { x: 5.2, y: 48 }, { x: 6.8, y: 75 }, { x: 7.1, y: 82 },
                    { x: 5.5, y: 52 }, { x: 7.9, y: 95 }, { x: 6.3, y: 68 }
                ],
                backgroundColor: '#3b82f6',
                pointRadius: 5,
                pointHoverRadius: 7
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: (context) => `Sleep: ${context.parsed.x}h, Readiness: ${context.parsed.y}`
                    }
                }
            },
            scales: {
                x: {
                    title: { display: true, text: 'Sleep (hours)', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                },
                y: {
                    title: { display: true, text: 'Readiness Score', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });

    // HRV vs Readiness Scatter
    new Chart(document.getElementById('hrvScatterChart'), {
        type: 'scatter',
        data: {
            datasets: [{
                label: 'Soldiers',
                data: [
                    { x: 65, y: 88 }, { x: 52, y: 72 }, { x: 48, y: 58 },
                    { x: 72, y: 92 }, { x: 55, y: 68 }, { x: 68, y: 85 },
                    { x: 42, y: 52 }, { x: 58, y: 75 }, { x: 62, y: 78 },
                    { x: 45, y: 55 }, { x: 75, y: 95 }, { x: 50, y: 65 }
                ],
                backgroundColor: '#10b981',
                pointRadius: 5,
                pointHoverRadius: 7
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                x: {
                    title: { display: true, text: 'HRV (ms)', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                },
                y: {
                    title: { display: true, text: 'Readiness Score', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });

    // Fatigue vs Readiness Scatter
    new Chart(document.getElementById('fatigueScatterChart'), {
        type: 'scatter',
        data: {
            datasets: [{
                label: 'Soldiers',
                data: [
                    { x: 25, y: 92 }, { x: 45, y: 75 }, { x: 62, y: 58 },
                    { x: 18, y: 95 }, { x: 52, y: 68 }, { x: 35, y: 85 },
                    { x: 75, y: 48 }, { x: 42, y: 72 }, { x: 38, y: 78 },
                    { x: 68, y: 55 }, { x: 22, y: 88 }, { x: 48, y: 65 }
                ],
                backgroundColor: '#ef4444',
                pointRadius: 5,
                pointHoverRadius: 7
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false }
            },
            scales: {
                x: {
                    title: { display: true, text: 'Fatigue Score', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                },
                y: {
                    title: { display: true, text: 'Readiness Score', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });
}

// === FORECAST CHARTS ===
function initializeForecastCharts() {

    // Readiness Forecast
    new Chart(document.getElementById('forecastChart'), {
        type: 'line',
        data: {
            labels: ['Today', '+1d', '+2d', '+3d', '+5d', '+7d', '+10d', '+14d'],
            datasets: [
                {
                    label: 'Historical',
                    data: [76, 75, 74, null, null, null, null, null],
                    borderColor: '#3b82f6',
                    backgroundColor: 'rgba(59, 130, 246, 0.1)',
                    fill: true,
                    borderWidth: 3,
                    tension: 0.4
                },
                {
                    label: 'Forecast',
                    data: [null, null, 74, 73, 72, 71, 70, 68],
                    borderColor: '#f59e0b',
                    backgroundColor: 'rgba(245, 158, 11, 0.1)',
                    fill: true,
                    borderWidth: 3,
                    borderDash: [5, 5],
                    tension: 0.4
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'top',
                    labels: { color: '#9ca3af', padding: 15 }
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
                    ticks: { color: '#9ca3af' }
                }
            }
        }
    });

    // Sleep Trend
    new Chart(document.getElementById('sleepTrendChart'), {
        type: 'line',
        data: {
            labels: ['Day 1', 'Day 3', 'Day 5', 'Day 7', 'Day 10', 'Day 14'],
            datasets: [{
                label: 'Avg Sleep Duration',
                data: [7.2, 6.8, 6.5, 6.2, 6.0, 5.8],
                borderColor: '#8b5cf6',
                backgroundColor: 'rgba(139, 92, 246, 0.1)',
                fill: true,
                tension: 0.4,
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                y: {
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

    // Fatigue Accumulation
    new Chart(document.getElementById('fatigueAccumChart'), {
        type: 'line',
        data: {
            labels: ['Day 1', 'Day 3', 'Day 5', 'Day 7', 'Day 10', 'Day 14'],
            datasets: [{
                label: 'Cumulative Fatigue',
                data: [12, 18, 25, 32, 42, 55],
                borderColor: '#ef4444',
                backgroundColor: 'rgba(239, 68, 68, 0.2)',
                fill: true,
                tension: 0.4,
                borderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                y: {
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

    // HRV Trend
    new Chart(document.getElementById('hrvTrendChart'), {
        type: 'line',
        data: {
            labels: ['Day 1', 'Day 3', 'Day 5', 'Day 7', 'Day 10', 'Day 14'],
            datasets: [
                {
                    label: 'Baseline',
                    data: [60, 60, 60, 60, 60, 60],
                    borderColor: '#6b7280',
                    borderWidth: 2,
                    borderDash: [5, 5],
                    pointRadius: 0
                },
                {
                    label: 'Current HRV',
                    data: [62, 58, 56, 54, 52, 51],
                    borderColor: '#10b981',
                    backgroundColor: 'rgba(16, 185, 129, 0.1)',
                    fill: true,
                    tension: 0.4,
                    borderWidth: 2
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false } },
            scales: {
                y: {
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

// === PARAMETER IMPACT CHARTS ===
function initializeParameterCharts() {

    // Sensitivity Chart
    new Chart(document.getElementById('sensitivityChart'), {
        type: 'bar',
        data: {
            labels: ['Sleep +10%', 'Sleep -10%', 'HRV +10%', 'HRV -10%', 'Fatigue +10%', 'Fatigue -10%'],
            datasets: [{
                label: 'Readiness Change',
                data: [4.2, -4.1, 2.8, -2.7, -3.5, 3.6],
                backgroundColor: function (context) {
                    return context.parsed.y >= 0 ? '#10b981' : '#ef4444';
                }
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
                    title: { display: true, text: 'Avg Readiness Change', color: '#9ca3af' },
                    grid: { color: 'rgba(255, 255, 255, 0.1)' },
                    ticks: { color: '#9ca3af' }
                },
                x: {
                    grid: { display: false },
                    ticks: { color: '#9ca3af', maxRotation: 45, minRotation: 45 }
                }
            }
        }
    });

    // Before/After Comparison
    new Chart(document.getElementById('beforeAfterChart'), {
        type: 'bar',
        data: {
            labels: ['Fit', 'Monitor', 'Risk'],
            datasets: [
                {
                    label: 'Before',
                    data: [130, 35, 18],
                    backgroundColor: 'rgba(59, 130, 246, 0.5)'
                },
                {
                    label: 'After (+10% Sleep)',
                    data: [142, 29, 12],
                    backgroundColor: 'rgba(16, 185, 129, 0.7)'
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'top',
                    labels: { color: '#9ca3af', padding: 15 }
                }
            },
            scales: {
                y: {
                    title: { display: true, text: 'Soldier Count', color: '#9ca3af' },
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
