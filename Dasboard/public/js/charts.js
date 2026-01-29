// Chart.js Integration for Dashboard

// Import Chart.js from CDN (already included in HTML)

let readinessChart = null;
let trainingChart = null;

// Initialize charts
function initializeCharts() {
    initReadinessTrendChart();
    initTrainingComparisonChart();
}

// Readiness Trend Chart (Line Chart)
async function initReadinessTrendChart() {
    const canvas = document.getElementById('readiness-trend-chart');
    if (!canvas) return;

    try {
        const token = getToken();

        // Fetch historical metrics (last 7 days of averages)
        const response = await fetch(`${API_URL}/soldiers`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const soldiers = await response.json();

        // Calculate historical trend (simulated - in real app would fetch from metrics table)
        const labels = ['6 days ago', '5 days ago', '4 days ago', '3 days ago', '2 days ago', 'Yesterday', 'Today'];
        const avgReadiness = soldiers.reduce((sum, s) => sum + s.readiness_score, 0) / soldiers.length;

        // Simulate variation for demo
        const data = labels.map((_, i) =>
            Math.round(avgReadiness - 5 + Math.random() * 10)
        );

        const ctx = canvas.getContext('2d');

        if (readinessChart) {
            readinessChart.destroy();
        }

        readinessChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Average Unit Readiness',
                    data: data,
                    borderColor: '#06b6d4',
                    backgroundColor: 'rgba(6, 182, 212, 0.1)',
                    fill: true,
                    tension: 0.4,
                    pointRadius: 4,
                    pointBackgroundColor: '#06b6d4'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(15, 23, 42, 0.9)',
                        titleColor: '#f8fafc',
                        bodyColor: '#e2e8f0',
                        borderColor: '#06b6d4',
                        borderWidth: 1
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            color: '#94a3b8'
                        },
                        grid: {
                            color: 'rgba(255, 255, 255, 0.05)'
                        }
                    },
                    x: {
                        ticks: {
                            color: '#94a3b8'
                        },
                        grid: {
                            color: 'rgba(255, 255, 255, 0.05)'
                        }
                    }
                }
            }
        });
    } catch (error) {
        console.error('Error initializing readiness chart:', error);
    }
}

// Training Comparison Chart (Bar Chart)
async function initTrainingComparisonChart() {
    const canvas = document.getElementById('training-comparison-chart');
    if (!canvas) return;

    try {
        const token = getToken();
        const response = await fetch(`${API_URL}/soldiers`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        const soldiers = await response.json();

        // Get top 6 soldiers by training completion
        const topSoldiers = soldiers
            .sort((a, b) => b.training_completion - a.training_completion)
            .slice(0, 6);

        const ctx = canvas.getContext('2d');

        if (trainingChart) {
            trainingChart.destroy();
        }

        trainingChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: topSoldiers.map(s => s.name.split(' ').slice(-1)[0]), // Last name
                datasets: [{
                    label: 'Training Completion %',
                    data: topSoldiers.map(s => s.training_completion),
                    backgroundColor: topSoldiers.map(s =>
                        s.training_completion >= 80 ? '#10b981' :
                            s.training_completion >= 60 ? '#f59e0b' : '#ef4444'
                    ),
                    borderColor: topSoldiers.map(s =>
                        s.training_completion >= 80 ? '#059669' :
                            s.training_completion >= 60 ? '#d97706' : '#dc2626'
                    ),
                    borderWidth: 2
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    },
                    tooltip: {
                        backgroundColor: 'rgba(15, 23, 42, 0.9)',
                        titleColor: '#f8fafc',
                        bodyColor: '#e2e8f0',
                        borderColor: '#06b6d4',
                        borderWidth: 1,
                        callbacks: {
                            label: (context) => {
                                return `${context.parsed.y}% Complete`;
                            }
                        }
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: 100,
                        ticks: {
                            color: '#94a3b8',
                            callback: (value) => value + '%'
                        },
                        grid: {
                            color: 'rgba(255, 255, 255, 0.05)'
                        }
                    },
                    x: {
                        ticks: {
                            color: '#94a3b8'
                        },
                        grid: {
                            display: false
                        }
                    }
                }
            }
        });
    } catch (error) {
        console.error('Error initializing training chart:', error);
    }
}

// Refresh charts with new data
function refreshCharts() {
    initReadinessTrendChart();
    initTrainingComparisonChart();
}

// Initialize charts when dashboard loads
if (document.querySelector('.main-board')) {
    document.addEventListener('DOMContentLoaded', () => {
        // Wait for Chart.js to load
        setTimeout(initializeCharts, 500);
    });
}

// Export functions
window.initializeCharts = initializeCharts;
window.refreshCharts = refreshCharts;
