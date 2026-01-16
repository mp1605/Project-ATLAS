// Dashboard Enhancements - Interactive Features
const API_URL = 'http://localhost:3000/api';

// ========== CALENDAR FUNCTIONS ==========

let currentMonth = new Date().getMonth();
let currentYear = new Date().getFullYear();
let events = [];

// Load events from API
async function loadEvents() {
    try {
        const token = getToken();
        const response = await fetch(`${API_URL}/events`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });
        events = await response.json();
        renderCalendar();
    } catch (error) {
        console.error('Error loading events:', error);
    }
}

// Render calendar with events
function renderCalendar() {
    const calendarGrid = document.querySelector('.calendar-grid');
    if (!calendarGrid) return;

    const firstDay = new Date(currentYear, currentMonth, 1).getDay();
    const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
    const prevDaysInMonth = new Date(currentYear, currentMonth, 0).getDate();

    // Clear existing dates (keep day names)
    const existingDates = calendarGrid.querySelectorAll('.cal-date');
    existingDates.forEach(el => el.remove());

    // Previous month faded dates
    for (let i = firstDay - 1; i >= 0; i--) {
        const dateDiv = createDateElement(prevDaysInMonth - i, 'faded', null);
        calendarGrid.appendChild(dateDiv);
    }

    // Current month dates
    const today = new Date();
    for (let day = 1; day <= daysInMonth; day++) {
        const dateString = `${currentYear}-${String(currentMonth + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        const isToday = day === today.getDate() && currentMonth === today.getMonth() && currentYear === today.getFullYear();
        const hasEvents = events.some(e => e.event_date === dateString);

        const dateDiv = createDateElement(day, isToday ? 'active' : '', hasEvents ? 'event-indicator' : '');
        dateDiv.setAttribute('data-date', dateString);
        dateDiv.addEventListener('click', () => showDateEvents(dateString));
        calendarGrid.appendChild(dateDiv);
    }
}

// Create date element
function createDateElement(day, className, extraClass) {
    const div = document.createElement('div');
    div.className = `cal-date ${className}`;
    if (extraClass) div.classList.add(extraClass);
    div.textContent = day;
    div.style.cursor = 'pointer';
    div.title = 'Click to view/add events';
    return div;
}

// Show events for a date
async function showDateEvents(date) {
    const dateEvents = events.filter(e => e.event_date === date);
    const formattedDate = new Date(date).toLocaleDateString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
    });

    const content = `
    <h3>Events for ${formattedDate}</h3>
    ${dateEvents.length > 0 ? `
      <div class="event-list">
        ${dateEvents.map(e => `
          <div class="event-item">
            <strong>${e.title}</strong>
            ${e.description ? `<p>${e.description}</p>` : ''}
            <button onclick="deleteEvent(${e.id})" class="btn-delete">Delete</button>
          </div>
        `).join('')}
      </div>
    ` : '<p>No events for this date.</p>'}
    <hr>
    <h4>Add New Event</h4>
    <form id="add-event-form" onsubmit="addEvent(event, '${date}')">
      <input type="text" id="event-title" placeholder="Event title" required>
      <textarea id="event-desc" placeholder="Description (optional)"></textarea>
      <button type="submit" class="btn-primary">Add Event</button>
    </form>
  `;

    showModal('Calendar Events', content);
}

// Add new event
async function addEvent(e, date) {
    e.preventDefault();
    const title = document.getElementById('event-title').value;
    const description = document.getElementById('event-desc').value;

    try {
        const token = getToken();
        const response = await fetch(`${API_URL}/events`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ title, description, event_date: date, event_type: 'general' })
        });

        if (response.ok) {
            closeModal();
            await loadEvents();
            alert('Event added successfully!');
        }
    } catch (error) {
        console.error('Error adding event:', error);
        alert('Failed to add event');
    }
}

// Delete event
async function deleteEvent(id) {
    if (!confirm('Delete this event?')) return;

    try {
        const token = getToken();
        const response = await fetch(`${API_URL}/events/${id}`, {
            method: 'DELETE',
            headers: { 'Authorization': `Bearer ${token}` }
        });

        if (response.ok) {
            await loadEvents();
            closeModal();
            alert('Event deleted!');
        }
    } catch (error) {
        console.error('Error deleting event:', error);
    }
}

// ========== ADD SOLDIER MODAL ==========

function showAddSoldierModal() {
    const content = `
    <form id="add-soldier-form" onsubmit="addSoldier(event)">
      <div class="form-group">
        <label>Full Name</label>
        <input type="text" id="soldier-name" required placeholder="SGT. John Doe">
      </div>
      <div class="form-group">
        <label>Rank</label>
        <select id="soldier-rank" required>
          <option value="">Select Rank</option>
          <option value="Private">Private (PVT)</option>
          <option value="Corporal">Corporal (CPL)</option>
          <option value="Sergeant">Sergeant (SGT)</option>
          <option value="Staff Sergeant">Staff Sergeant (SSG)</option>
          <option value="Lieutenant">Lieutenant (LT)</option>
          <option value="Captain">Captain (CPT)</option>
        </select>
      </div>
      <div class="form-group">
        <label>Unit</label>
        <input type="text" id="soldier-unit" placeholder="Alpha Company">
      </div>
      <div class="form-group">
        <label>Initial Readiness Score (0-100)</label>
        <input type="number" id="soldier-readiness" min="0" max="100" value="50">
      </div>
      <div class="form-group">
        <label>Training Completion % (0-100)</label>
        <input type="number" id="soldier-training" min="0" max="100" value="0">
      </div>
      <button type="submit" class="btn-primary">Add Soldier</button>
    </form>
  `;

    showModal('Add New Soldier', content);
}

async function addSoldier(e) {
    e.preventDefault();

    const data = {
        name: document.getElementById('soldier-name').value,
        rank: document.getElementById('soldier-rank').value,
        unit: document.getElementById('soldier-unit').value,
        readiness_score: parseInt(document.getElementById('soldier-readiness').value),
        training_completion: parseInt(document.getElementById('soldier-training').value)
    };

    try {
        const token = getToken();
        const response = await fetch(`${API_URL}/soldiers`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${token}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(data)
        });

        if (response.ok) {
            closeModal();
            loadDashboardData(); // Refresh dashboard
            alert('Soldier added successfully!');
        } else {
            const error = await response.json();
            alert(error.error || 'Failed to add soldier');
        }
    } catch (error) {
        console.error('Error adding soldier:', error);
        alert('Failed to add soldier');
    }
}

// ========== SEARCH & FILTER ==========

let allSoldiers = [];

// Store all soldiers for filtering
function storeAllSoldiers(soldiers) {
    allSoldiers = soldiers;
}

// Filter soldiers
function filterSoldiers() {
    const searchTerm = document.getElementById('soldier-search')?.value.toLowerCase() || '';
    const statusFilter = document.getElementById('status-filter')?.value || 'all';

    let filtered = allSoldiers.filter(soldier => {
        const matchesSearch = soldier.name.toLowerCase().includes(searchTerm) ||
            soldier.rank.toLowerCase().includes(searchTerm) ||
            (soldier.unit && soldier.unit.toLowerCase().includes(searchTerm));

        let matchesStatus = true;
        if (statusFilter !== 'all') {
            if (statusFilter === 'ready') matchesStatus = soldier.readiness_score >= 70;
            else if (statusFilter === 'at-risk') matchesStatus = soldier.readiness_score >= 40 && soldier.readiness_score < 70;
            else if (statusFilter === 'not-ready') matchesStatus = soldier.readiness_score < 40;
        }

        return matchesSearch && matchesStatus;
    });

    updateSoldierList(filtered);
}

// Update soldier list with filtered results
function updateSoldierList(soldiers) {
    const soldierList = document.querySelector('.mini-soldier-list');
    if (!soldierList) return;

    if (soldiers.length === 0) {
        soldierList.innerHTML = '<p style="text-align:center; color:var(--text-gray);">No soldiers found</p>';
        return;
    }

    soldierList.innerHTML = soldiers.slice(0, 10).map(soldier => `
    <a href="soldier_detail.html?id=${soldier.id}" class="soldier-row-text">
      <div class="s-name">${soldier.name}</div>
      <div class="s-info">
        <span class="score-${getScoreClass(soldier.readiness_score)}">${soldier.readiness_score}</span>
        • ${calculateTimeAgo(soldier.last_assessment)}
      </div>
    </a>
  `).join('') + (soldiers.length > 10 ? '<a href="#" class="show-more">Show more ></a>' : '');
}

// ========== MODAL SYSTEM ==========

function showModal(title, content) {
    let modal = document.getElementById('generic-modal');
    if (!modal) {
        modal = document.createElement('div');
        modal.id = 'generic-modal';
        modal.className = 'modal';
        document.body.appendChild(modal);
    }

    modal.innerHTML = `
    <div class="modal-content glass-panel">
      <div class="modal-header">
        <h2>${title}</h2>
        <span class="close-modal" onclick="closeModal()">&times;</span>
      </div>
      <div class="modal-body">${content}</div>
    </div>
  `;
    modal.style.display = 'flex';
}

function closeModal() {
    const modal = document.getElementById('generic-modal');
    if (modal) modal.style.display = 'none';
}

// Close modal on outside click
window.onclick = function (event) {
    const modal = document.getElementById('generic-modal');
    if (event.target === modal) {
        closeModal();
    }
};

// ========== INITIALIZE ENHANCEMENTS ==========

document.addEventListener('DOMContentLoaded', () => {
    // Initialize calendar
    if (document.querySelector('.calendar-grid')) {
        loadEvents();
    }

    // Add search functionality
    const searchInput = document.getElementById('soldier-search');
    if (searchInput) {
        searchInput.addEventListener('input', filterSoldiers);
    }

    const statusFilter = document.getElementById('status-filter');
    if (statusFilter) {
        statusFilter.addEventListener('change', filterSoldiers);
    }

    // Add Soldier button
    const addSoldierBtn = document.getElementById('add-soldier-btn');
    if (addSoldierBtn) {
        addSoldierBtn.addEventListener('click', showAddSoldierModal);
    }
});

// Make functions globally available
window.deleteEvent = deleteEvent;
window.addEvent = addEvent;
window.addSoldier = addSoldier;
window.closeModal = closeModal;
window.showAddSoldierModal = showAddSoldierModal;
