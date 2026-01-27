// Readiness Scores Integration with Backend API
// API Base URL
const API_BASE_URL = 'http://192.168.0.108:3000';

// Score metadata for display
const scoreMetadata = [
    { key: 'readiness', label: 'Overall Readiness', unit: '/100', color: '#3b82f6' },
    { key: 'fatigue_index', label: 'Fatigue Index', unit: '/100', color: '#f59e0b' },
    { key: 'recovery', label: 'Recovery Score', unit: '/100', color: '#10b981' },
    { key: 'sleep_quality', label: 'Sleep Quality', unit: '/100', color: '#8b5cf6' },
    { key: 'sleep_debt', label: 'Sleep Debt', unit: ' hrs', color: '#ef4444' },
    { key: 'autonomic_balance', label: 'Autonomic Balance', unit: '/100', color: '#06b6d4' },
    { key: 'hrv_deviation', label: 'HRV Deviation', unit: '%', color: '#ec4899' },
    { key: 'resting_hr_deviation', label: 'Resting HR Deviation', unit: '%', color: '#f97316' },
    { key: 'respiratory_stability', label: 'Respiratory Stability', unit: '/100', color: '#14b8a6' },
    { key: 'oxygen_stability', label: 'Oxygen Saturation Stability', unit: '/100', color: '#0ea5e9' },
    { key: 'training_load', label: 'Training Load', unit: '/100', color: '#8b5cf6' },
    { key: 'acute_chronic_ratio', label: 'Acute/Chronic Load Ratio', unit: ':1', color: '#f59e0b' },
    { key: 'cardiovascular_strain', label: 'Cardiovascular Strain', unit: '/100', color: '#ef4444' },
    { key: 'stress_load', label: 'Stress Load', unit: '/100', color: '#f97316' },
    { key: 'illness_risk', label: 'Illness Risk', unit: '%', color: '#dc2626' },
    { key: 'overtraining_risk', label: 'Overtraining Risk', unit: '%', color: '#ea580c' },
    { key: 'energy_availability', label: 'Energy Availability', unit: '/100', color: '#10b981' },
    { key: 'physical_status', label: 'Physical Status Index', unit: '/100', color: '#3b82f6' },
];

// Create score card HTML
function createScoreCard(scoreData, metadata) {
    const value = scoreData[metadata.key];
    const displayValue = typeof value === 'number' ? value.toFixed(1) : '--';

    return `
        <div class="kpi-card">
            <div class="kpi-header">
                <h3>${metadata.label}</h3>
            </div>
            <div class="kpi-large-value">
                <div class="large-number" style="color: ${metadata.color};">${displayValue}</div>
                <div class="large-unit">${metadata.unit}</div>
            </div>
            <div class="kpi-sublabel">Latest Reading</div>
        </div>
    `;
}

// Load readiness scores from API
async function loadReadinessScores() {
    const scoresGrid = document.getElementById('scores-grid');
    const loadingState = document.getElementById('loading-state');
    const errorState = document.getElementById('error-state');

    // ✅ REQUIRE AUTH - redirect to login if not authenticated
    if (!authClient.requireAuth()) {
        return;
    }

    // Show loading
    scoresGrid.style.display = 'none';
    errorState.style.display = 'none';
    loadingState.style.display = 'block';

    try {
        // ✅ Get user ID from URL parameters
        const urlParams = new URLSearchParams(window.location.search);
        const userId = urlParams.get('email') || 'meghp169@gmail.com';

        // ✅ Fetch latest scores with Bearer token (NO HARDCODED TOKENS)
        const response = await authClient.fetchWithAuth(
            `${API_BASE_URL}/api/v1/readiness/${userId}/latest`,
            { method: 'GET' }
        );

        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        const data = await response.json();
        console.log('✅ Loaded readiness scores:', data);

        // Comprehensive mapping of all 18 readiness metrics
        // Maps legacy or alternative keys to the standardized dashboard names
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

        // Normalize scores map
        const normalizedScores = {};
        Object.entries(data.scores || {}).forEach(([key, value]) => {
            const standardKey = keyMap[key] || key;
            normalizedScores[standardKey] = value;
        });

        // Generate score cards
        const cardsHTML = scoreMetadata.map(meta =>
            createScoreCard(normalizedScores, meta)
        ).join('');

        scoresGrid.innerHTML = cardsHTML;

        // Show scores grid
        loadingState.style.display = 'none';
        scoresGrid.style.display = 'grid';

        // Update metadata display
        updateMetadata(data);

    } catch (error) {
        console.error('❌ Failed to load readiness scores:', error);

        // Show error state
        loadingState.style.display = 'none';
        scoresGrid.style.display = 'none';
        errorState.style.display = 'block';
        errorState.querySelector('div').textContent = `Failed to load scores: ${error.message}`;
    }
}

// Update metadata (category, confidence, timestamp)
function updateMetadata(data) {
    // Update sync info if available
    const syncInfo = document.querySelector('.sync-text-compact');
    if (syncInfo && data.timestamp) {
        const timestamp = new Date(data.timestamp);
        const now = new Date();
        const diffMinutes = Math.floor((now - timestamp) / 60000);

        if (diffMinutes < 60) {
            syncInfo.textContent = `Last sync: ${diffMinutes}m ago`;
        } else {
            const diffHours = Math.floor(diffMinutes / 60);
            syncInfo.textContent = `Last sync: ${diffHours}h ago`;
        }
    }

    // Update status badge if available
    const statusBadge = document.querySelector('.status-badge-integrated');
    if (statusBadge && data.category) {
        statusBadge.textContent = data.category;
        statusBadge.className = `status-badge-integrated status-${data.category.toLowerCase()}`;
    }

    // Update completeness if available
    const completenessValue = document.querySelector('.completeness-value');
    if (completenessValue && data.metadata && data.metadata.data_completeness) {
        completenessValue.textContent = `${data.metadata.data_completeness}%`;
    }
}

// Auto-load scores on page load
document.addEventListener('DOMContentLoaded', function () {
    console.log('📊 Dashboard loaded - fetching readiness scores...');
    loadReadinessScores();
});

// Auto-refresh every 5 minutes
setInterval(loadReadinessScores, 5 * 60 * 1000);
