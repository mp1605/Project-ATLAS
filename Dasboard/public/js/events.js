// Events Management JavaScript

// Sample event data
let eventsData = [
    {
        id: 1,
        name: "High-Load Endurance Training",
        type: "training",
        date: "2026-01-12",
        duration: 4,
        affectedUnits: "Charlie Company",
        notes: "Intense cardiovascular and strength training session",
        impact: {
            before: { readiness: 72, hrv: 65, fatigue: 48, sleep: 7.2 },
            after: { readiness: 65, hrv: 58, fatigue: 63, sleep: 6.8 }
        }
    },
    {
        id: 2,
        name: "Mission - Extended Operation",
        type: "mission",
        date: "2026-01-10",
        duration: 14,
        affectedUnits: "Charlie Company, 1st Platoon",
        notes: "14-hour operational mission",
        impact: {
            before: { readiness: 75, hrv: 68, fatigue: 45, sleep: 7.5 },
            after: { readiness: 62, hrv: 55, fatigue: 68, sleep: 5.9 }
        }
    },
    {
        id: 3,
        name: "Scheduled Recovery Day",
        type: "recovery",
        date: "2026-01-08",
        duration: 8,
        affectedUnits: "All Units",
        notes: "Company-wide recovery and light activity",
        impact: {
            before: { readiness: 68, hrv: 60, fatigue: 55, sleep: 6.5 },
            after: { readiness: 74, hrv: 66, fatigue: 42, sleep: 7.8 }
        }
    },
    {
        id: 4,
        name: "ACFT - Army Combat Fitness Test",
        type: "test",
        date: "2026-01-05",
        duration: 3,
        affectedUnits: "Charlie Company",
        notes: "Bi-annual physical fitness assessment",
        impact: {
            before: { readiness: 70, hrv: 64, fatigue: 50, sleep: 7.0 },
            after: { readiness: 66, hrv: 60, fatigue: 58, sleep: 6.6 }
        }
    },
    {
        id: 5,
        name: "Parameter Weight Adjustment",
        type: "admin",
        date: "2026-01-05",
        duration: 0.5,
        affectedUnits: "System Configuration",
        notes: "Sleep weight increased from 25% to 30%"
    },
    {
        id: 6,
        name: "Night Operations Training",
        type: "mission",
        date: "2026-01-15",
        duration: 8,
        affectedUnits: "2nd Platoon",
        notes: "Night vision and tactical operations"
    },
    {
        id: 7,
        name: "Strength Training",
        type: "training",
        date: "2026-01-18",
        duration: 2,
        affectedUnits: "Charlie Company",
        notes: "Upper body and core strength focus"
    },
    {
        id: 8,
        name: "Medical Checkup",
        type: "admin",
        date: "2026-01-20",
        duration: 4,
        affectedUnits: "All Personnel",
        notes: "Quarterly health screening"
    },
    {
        id: 9,
        name: "Long-Distance Run",
        type: "training",
        date: "2026-01-22",
        duration: 2.5,
        affectedUnits: "Charlie Company",
        notes: "10km endurance run"
    },
    {
        id: 10,
        name: "Rest and Recovery",
        type: "recovery",
        date: "2026-01-25",
        duration: 8,
        affectedUnits: "All Units",
        notes: "Scheduled recovery after intensive week"
    }
];

// Current calendar state
let currentDate = new Date(2026, 0, 1); // January 2026

// Initialize page
document.addEventListener('DOMContentLoaded', function () {
    renderCalendar();
    renderTimeline();
    populateImpactSelector();
    initializeEventListeners();
});

// Tab switching
function switchEventTab(tabName) {
    // Update tab buttons
    const allTabs = document.querySelectorAll('.detail-tab-btn');
    allTabs.forEach(tab => tab.classList.remove('active'));
    event.target.closest('.detail-tab-btn').classList.add('active');

    // Update tab content
    const allViews = document.querySelectorAll('.event-view');
    allViews.forEach(view => view.classList.remove('active'));
    document.getElementById(tabName + 'View').classList.add('active');
}

// ========== CALENDAR VIEW ==========

function renderCalendar() {
    const calendarGrid = document.getElementById('calendarGrid');
    const monthLabel = document.getElementById('calendarMonth');

    // Update month label
    const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'];
    monthLabel.textContent = `${monthNames[currentDate.getMonth()]} ${currentDate.getFullYear()}`;

    // Clear grid
    calendarGrid.innerHTML = '';

    // Add day headers
    const dayHeaders = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    dayHeaders.forEach(day => {
        const header = document.createElement('div');
        header.className = 'calendar-day-header';
        header.textContent = day;
        calendarGrid.appendChild(header);
    });

    // Get calendar data
    const year = currentDate.getFullYear();
    const month = currentDate.getMonth();
    const firstDay = new Date(year, month, 1).getDay();
    const daysInMonth = new Date(year, month + 1, 0).getDate();
    const daysInPrevMonth = new Date(year, month, 0).getDate();

    const today = new Date();
    const isCurrentMonth = today.getMonth() === month && today.getFullYear() === year;

    // Previous month days
    for (let i = firstDay - 1; i >= 0; i--) {
        const dayDiv = createDayCell(daysInPrevMonth - i, true, null);
        calendarGrid.appendChild(dayDiv);
    }

    // Current month days
    for (let day = 1; day <= daysInMonth; day++) {
        const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        const dayEvents = eventsData.filter(e => e.date === dateStr);
        const isToday = isCurrentMonth && day === today.getDate();

        const dayDiv = createDayCell(day, false, dayEvents, isToday);
        calendarGrid.appendChild(dayDiv);
    }

    // Next month days
    const totalCells = firstDay + daysInMonth;
    const remainingCells = totalCells % 7 === 0 ? 0 : 7 - (totalCells % 7);
    for (let day = 1; day <= remainingCells; day++) {
        const dayDiv = createDayCell(day, true, null);
        calendarGrid.appendChild(dayDiv);
    }
}

function createDayCell(dayNumber, isOtherMonth, events, isToday = false) {
    const dayDiv = document.createElement('div');
    dayDiv.className = 'calendar-day';
    if (isOtherMonth) dayDiv.classList.add('other-month');
    if (isToday) dayDiv.classList.add('today');

    const dayNum = document.createElement('div');
    dayNum.className = 'day-number';
    dayNum.textContent = dayNumber;
    dayDiv.appendChild(dayNum);

    if (events && events.length > 0) {
        const eventsContainer = document.createElement('div');
        eventsContainer.className = 'day-events';

        events.forEach(event => {
            const dot = document.createElement('span');
            dot.className = `event-dot event-${event.type}`;
            dot.title = event.name;
            eventsContainer.appendChild(dot);
        });

        dayDiv.appendChild(eventsContainer);
        dayDiv.onclick = () => showDayEvents(events);
    }

    return dayDiv;
}

function showDayEvents(events) {
    const modal = document.getElementById('eventDetailsModal');
    const modalBody = document.getElementById('modalEventBody');

    modalBody.innerHTML = events.map(event => `
        <div class="timeline-item type-${event.type}" style="margin-bottom: 16px;">
            <div class="timeline-date">${formatDate(event.date)}</div>
            <div class="timeline-type">
                <span class="timeline-type-icon event-${event.type}"></span>
                ${event.type.toUpperCase()}
            </div>
            <div class="timeline-summary">
                <div class="timeline-title">${event.name}</div>
                <div class="timeline-description">${event.notes || 'No description'}</div>
            </div>
            <div class="timeline-meta">
                <span>${event.duration}h</span>
                <span>${event.affectedUnits}</span>
            </div>
        </div>
    `).join('');

    modal.classList.add('active');
}

function closeEventModal() {
    document.getElementById('eventDetailsModal').classList.remove('active');
}

function previousMonth() {
    currentDate.setMonth(currentDate.getMonth() - 1);
    renderCalendar();
}

function nextMonth() {
    currentDate.setMonth(currentDate.getMonth() + 1);
    renderCalendar();
}

// ========== TIMELINE VIEW ==========

function renderTimeline() {
    const container = document.getElementById('timelineContainer');
    const sortedEvents = [...eventsData].sort((a, b) => new Date(b.date) - new Date(a.date));

    container.innerHTML = sortedEvents.map(event => `
        <div class="timeline-item type-${event.type}" onclick="showEventDetails(${event.id})">
            <div class="timeline-date">${formatDate(event.date)}</div>
            <div class="timeline-type">
                <span class="timeline-type-icon event-${event.type}"></span>
                ${event.type.toUpperCase()}
            </div>
            <div class="timeline-summary">
                <div class="timeline-title">${event.name}</div>
                <div class="timeline-description">${event.notes || 'No description'}</div>
            </div>
            <div class="timeline-meta">
                <span>Duration: ${event.duration}h</span>
                <span>${event.affectedUnits}</span>
            </div>
        </div>
    `).join('');
}

function sortTimeline() {
    const sortBy = document.getElementById('timelineSort').value;
    const container = document.getElementById('timelineContainer');
    let sortedEvents = [...eventsData];

    if (sortBy === 'date-desc') {
        sortedEvents.sort((a, b) => new Date(b.date) - new Date(a.date));
    } else if (sortBy === 'date-asc') {
        sortedEvents.sort((a, b) => new Date(a.date) - new Date(b.date));
    } else if (sortBy === 'type') {
        sortedEvents.sort((a, b) => a.type.localeCompare(b.type));
    }

    container.innerHTML = sortedEvents.map(event => `
        <div class="timeline-item type-${event.type}" onclick="showEventDetails(${event.id})">
            <div class="timeline-date">${formatDate(event.date)}</div>
            <div class="timeline-type">
                <span class="timeline-type-icon event-${event.type}"></span>
                ${event.type.toUpperCase()}
            </div>
            <div class="timeline-summary">
                <div class="timeline-title">${event.name}</div>
                <div class="timeline-description">${event.notes || 'No description'}</div>
            </div>
            <div class="timeline-meta">
                <span>Duration: ${event.duration}h</span>
                <span>${event.affectedUnits}</span>
            </div>
        </div>
    `).join('');
}

function showEventDetails(eventId) {
    const event = eventsData.find(e => e.id === eventId);
    if (!event) return;

    const modal = document.getElementById('eventDetailsModal');
    const modalBody = document.getElementById('modalEventBody');

    modalBody.innerHTML = `
        <div class="timeline-item type-${event.type}">
            <div class="timeline-date">${formatDate(event.date)}</div>
            <div class="timeline-type">
                <span class="timeline-type-icon event-${event.type}"></span>
                ${event.type.toUpperCase()}
            </div>
            <div class="timeline-summary">
                <div class="timeline-title">${event.name}</div>
                <div class="timeline-description">${event.notes || 'No description'}</div>
            </div>
            <div class="timeline-meta">
                <span>Duration: ${event.duration}h</span>
                <span>${event.affectedUnits}</span>
            </div>
        </div>
    `;

    modal.classList.add('active');
}

// ========== IMPACT VIEW ==========

function populateImpactSelector() {
    const select = document.getElementById('impactEventSelect');
    const eventsWithImpact = eventsData.filter(e => e.impact);

    select.innerHTML = '<option value="">Choose an event...</option>' +
        eventsWithImpact.map(event =>
            `<option value="${event.id}">${formatDate(event.date)} - ${event.name}</option>`
        ).join('');
}

function loadEventImpact() {
    const eventId = parseInt(document.getElementById('impactEventSelect').value);
    if (!eventId) {
        document.getElementById('impactContent').innerHTML = `
            <div class="impact-placeholder">
                <svg viewBox="0 0 24 24" width="48" height="48" fill="currentColor" opacity="0.3">
                    <path d="M16 6l2.29 2.29-4.88 4.88-4-4L2 16.59 3.41 18l6-6 4 4 6.3-6.29L22 12V6z" />
                </svg>
                <p>Select an event to view its impact on metrics</p>
            </div>
        `;
        return;
    }

    const event = eventsData.find(e => e.id === eventId);
    if (!event || !event.impact) return;

    const { before, after } = event.impact;

    document.getElementById('impactContent').innerHTML = `
        <div class="impact-header">
            <div class="impact-event-name">${event.name}</div>
            <div class="impact-event-date">${formatDate(event.date)} • ${event.duration} hours</div>
        </div>
        
        <div class="impact-comparison">
            <div class="impact-section">
                <div class="impact-section-title">Before Event (3-day avg)</div>
                <div class="impact-metrics">
                    <div class="impact-metric">
                        <span class="metric-label">Avg Readiness</span>
                        <span class="metric-value">${before.readiness}</span>
                    </div>
                    <div class="impact-metric">
                        <span class="metric-label">HRV Score</span>
                        <span class="metric-value">${before.hrv}</span>
                    </div>
                    <div class="impact-metric">
                        <span class="metric-label">Fatigue Index</span>
                        <span class="metric-value">${before.fatigue}</span>
                    </div>
                    <div class="impact-metric">
                        <span class="metric-label">Sleep Quality</span>
                        <span class="metric-value">${before.sleep}h</span>
                    </div>
                </div>
            </div>
            
            <div class="impact-section">
                <div class="impact-section-title">After Event (3-day avg)</div>
                <div class="impact-metrics">
                    <div class="impact-metric">
                        <span class="metric-label">Avg Readiness</span>
                        <span class="metric-value">${after.readiness}</span>
                    </div>
                    <div class="impact-metric">
                        <span class="metric-label">HRV Score</span>
                        <span class="metric-value">${after.hrv}</span>
                    </div>
                    <div class="impact-metric">
                        <span class="metric-label">Fatigue Index</span>
                        <span class="metric-value">${after.fatigue}</span>
                    </div>
                    <div class="impact-metric">
                        <span class="metric-label">Sleep Quality</span>
                        <span class="metric-value">${after.sleep}h</span>
                    </div>
                </div>
            </div>
        </div>
        
        <div class="impact-visual">
            ${createMetricBarComparison('Readiness', before.readiness, after.readiness, 100)}
            ${createMetricBarComparison('HRV Score', before.hrv, after.hrv, 100)}
            ${createMetricBarComparison('Fatigue Index', before.fatigue, after.fatigue, 100)}
            ${createMetricBarComparison('Sleep Quality', before.sleep, after.sleep, 10)}
        </div>
    `;
}

function createMetricBarComparison(name, before, after, max) {
    const change = after - before;
    const changePercent = ((change / before) * 100).toFixed(1);
    const isPositive = change > 0;
    const arrow = isPositive ? '↑' : '↓';

    // For fatigue, lower is better, so invert the color logic
    const isFatigue = name === 'Fatigue Index';
    const colorClass = isFatigue ?
        (isPositive ? 'negative' : 'positive') :
        (isPositive ? 'positive' : 'negative');

    const beforeWidth = (before / max) * 100;
    const afterWidth = (after / max) * 100;

    return `
        <div class="metric-bar-container">
            <div class="metric-bar-label">
                <span class="metric-bar-name">${name}</span>
                <span class="metric-change ${colorClass}">
                    ${arrow} ${Math.abs(change).toFixed(1)} (${Math.abs(changePercent)}%)
                </span>
            </div>
            <div class="metric-bars">
                <div class="metric-bar bar-before" style="width: ${beforeWidth}%">${before}</div>
                <div class="metric-bar bar-after" style="width: ${afterWidth}%">${after}</div>
            </div>
        </div>
    `;
}

// ========== EVENT MANAGEMENT ==========

function openAddEventModal() {
    document.getElementById('addEventModal').classList.add('active');
    document.getElementById('addEventForm').reset();
    // Set default date to today
    document.getElementById('eventDate').valueAsDate = new Date();
}

function closeAddEventModal() {
    document.getElementById('addEventModal').classList.remove('active');
}

function initializeEventListeners() {
    // Search functionality
    const searchInput = document.getElementById('timelineSearch');
    if (searchInput) {
        searchInput.addEventListener('input', filterTimeline);
    }

    // Event type filter
    const typeFilter = document.getElementById('eventTypeFilter');
    if (typeFilter) {
        typeFilter.addEventListener('change', filterTimeline);
    }

    // Add event form
    const form = document.getElementById('addEventForm');
    if (form) {
        form.addEventListener('submit', handleAddEvent);
    }

    // Close modals on background click
    document.querySelectorAll('.modal').forEach(modal => {
        modal.addEventListener('click', (e) => {
            if (e.target === modal) {
                modal.classList.remove('active');
            }
        });
    });
}

function filterTimeline() {
    const searchTerm = document.getElementById('timelineSearch').value.toLowerCase();
    const typeFilter = document.getElementById('eventTypeFilter').value;

    let filteredEvents = eventsData.filter(event => {
        const matchesSearch = event.name.toLowerCase().includes(searchTerm) ||
            event.notes?.toLowerCase().includes(searchTerm) ||
            event.affectedUnits.toLowerCase().includes(searchTerm);
        const matchesType = typeFilter === 'all' || event.type === typeFilter;

        return matchesSearch && matchesType;
    });

    // Sort by date (newest first)
    filteredEvents.sort((a, b) => new Date(b.date) - new Date(a.date));

    const container = document.getElementById('timelineContainer');
    if (filteredEvents.length === 0) {
        container.innerHTML = '<div class="impact-placeholder"><p>No events found</p></div>';
        return;
    }

    container.innerHTML = filteredEvents.map(event => `
        <div class="timeline-item type-${event.type}" onclick="showEventDetails(${event.id})">
            <div class="timeline-date">${formatDate(event.date)}</div>
            <div class="timeline-type">
                <span class="timeline-type-icon event-${event.type}"></span>
                ${event.type.toUpperCase()}
            </div>
            <div class="timeline-summary">
                <div class="timeline-title">${event.name}</div>
                <div class="timeline-description">${event.notes || 'No description'}</div>
            </div>
            <div class="timeline-meta">
                <span>Duration: ${event.duration}h</span>
                <span>${event.affectedUnits}</span>
            </div>
        </div>
    `).join('');
}

function handleAddEvent(e) {
    e.preventDefault();

    const newEvent = {
        id: eventsData.length + 1,
        name: document.getElementById('eventName').value,
        type: document.getElementById('eventType').value,
        date: document.getElementById('eventDate').value,
        duration: parseFloat(document.getElementById('eventDuration').value),
        affectedUnits: document.getElementById('affectedUnits').value || 'Unspecified',
        notes: document.getElementById('eventNotes').value
    };

    eventsData.push(newEvent);

    // Refresh all views
    renderCalendar();
    renderTimeline();
    populateImpactSelector();

    // Close modal
    closeAddEventModal();

    // Show success message (you could add a toast notification here)
    console.log('Event added successfully:', newEvent);
}

// ========== UTILITY FUNCTIONS ==========

function formatDate(dateStr) {
    const date = new Date(dateStr + 'T00:00:00');
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
}
