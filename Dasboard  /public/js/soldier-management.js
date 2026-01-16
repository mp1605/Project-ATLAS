// Soldier Management JavaScript
// Handles search, filtering, sorting, and pagination for the enhanced soldier table

document.addEventListener('DOMContentLoaded', function() {
    console.log('Soldier Management initialized');
    
    // State management
    let allSoldiers = [];
    let filteredSoldiers = [];
    let currentPage = 1;
    const rowsPerPage = 10;
    let currentSort = { column: null, ascending: true };
    
    // DOM elements
    const searchBar = document.getElementById('soldierSearch');
    const statusFilter = document.getElementById('statusFilter');
    const tableBody = document.getElementById('soldierTableBody');
    const selectAllCheckbox = document.getElementById('selectAll');
    const bulkExportBtn = document.getElementById('bulkExport');
    const bulkNotifyBtn = document.getElementById('bulkNotify');
    const prevPageBtn = document.getElementById('prevPage');
    const nextPageBtn = document.getElementById('nextPage');
    const currentPageSpan = document.getElementById('currentPage');
    const totalPagesSpan = document.getElementById('totalPages');
    
    // Initialize soldiers data from table rows
    function initializeSoldiers() {
        const rows = tableBody.querySelectorAll('.table-row');
        allSoldiers = Array.from(rows).map((row, index) => ({
            element: row,
            index: index,
            name: row.querySelector('.soldier-name').textContent.trim(),
            rank: row.querySelector('.soldier-rank').textContent.trim(),
            mos: row.querySelector('.mos-badge').textContent.trim(),
            readiness: parseInt(row.querySelector('.badge').textContent.trim()),
            deployment: row.querySelector('.status-pill').textContent.trim(),
            status: row.getAttribute('data-status')
        }));
        filteredSoldiers = [...allSoldiers];
        renderTable();
    }
    
    // Search functionality
    if (searchBar) {
        searchBar.addEventListener('input', function(e) {
            const query = e.target.value.toLowerCase();
            filterSoldiers(query, statusFilter.value);
        });
    }
    
    // Status filter functionality
    if (statusFilter) {
        statusFilter.addEventListener('change', function(e) {
            const query = searchBar ? searchBar.value.toLowerCase() : '';
            filterSoldiers(query, e.target.value);
        });
    }
    
    // Filter soldiers based on search and status
    function filterSoldiers(searchQuery, statusValue) {
        filteredSoldiers = allSoldiers.filter(soldier => {
            const matchesSearch = 
                soldier.name.toLowerCase().includes(searchQuery) ||
                soldier.rank.toLowerCase().includes(searchQuery) ||
                soldier.mos.toLowerCase().includes(searchQuery);
            
            const matchesStatus = 
                statusValue === 'all' || 
                soldier.status === statusValue;
            
            return matchesSearch && matchesStatus;
        });
        
        currentPage = 1;
        renderTable();
    }
    
    // Column sorting
    const sortableHeaders = document.querySelectorAll('.sortable');
    sortableHeaders.forEach(header => {
        header.addEventListener('click', function() {
            const column = this.getAttribute('data-sort');
            
            if (currentSort.column === column) {
                currentSort.ascending = !currentSort.ascending;
            } else {
                currentSort.column = column;
                currentSort.ascending = true;
            }
            
            sortSoldiers(column, currentSort.ascending);
        });
    });
    
    // Sort soldiers by column
    function sortSoldiers(column, ascending) {
        filteredSoldiers.sort((a, b) => {
            let aVal, bVal;
            
            switch(column) {
                case 'name':
                    aVal = a.name;
                    bVal = b.name;
                    break;
                case 'mos':
                    aVal = a.mos;
                    bVal = b.mos;
                    break;
                case 'readiness':
                    aVal = a.readiness;
                    bVal = b.readiness;
                    break;
                case 'deployment':
                    aVal = a.deployment;
                    bVal = b.deployment;
                    break;
                default:
                    return 0;
            }
            
            if (typeof aVal === 'string') {
                return ascending ? 
                    aVal.localeCompare(bVal) : 
                    bVal.localeCompare(aVal);
            } else {
                return ascending ? aVal - bVal : bVal - aVal;
            }
        });
        
        renderTable();
    }
    
    // Pagination
    if (prevPageBtn) {
        prevPageBtn.addEventListener('click', () => {
            if (currentPage > 1) {
                currentPage--;
                renderTable();
            }
        });
    }
    
    if (nextPageBtn) {
        nextPageBtn.addEventListener('click', () => {
            const totalPages = Math.ceil(filteredSoldiers.length / rowsPerPage);
            if (currentPage < totalPages) {
                currentPage++;
                renderTable();
            }
        });
    }
    
    // Render table with current filters, sorting, and pagination
    function renderTable() {
        // Clear current table
        tableBody.innerHTML = '';
        
        // Calculate pagination
        const totalPages = Math.ceil(filteredSoldiers.length / rowsPerPage);
        const startIndex = (currentPage - 1) * rowsPerPage;
        const endIndex = Math.min(startIndex + rowsPerPage, filteredSoldiers.length);
        
        // Show current page soldiers
        for (let i = startIndex; i < endIndex; i++) {
            tableBody.appendChild(filteredSoldiers[i].element.cloneNode(true));
        }
        
        // Reattach checkbox listeners
        attachCheckboxListeners();
        
        // Update pagination UI
        if (currentPageSpan) currentPageSpan.textContent = currentPage;
        if (totalPagesSpan) totalPagesSpan.textContent = totalPages || 1;
        
        if (prevPageBtn) {
            prevPageBtn.disabled = currentPage === 1;
        }
        
        if (nextPageBtn) {
            nextPageBtn.disabled = currentPage >= totalPages;
        }
        
        // Show message if no results
        if (filteredSoldiers.length === 0) {
            tableBody.innerHTML = `
                <tr>
                    <td colspan="9" style="text-align: center; padding: 40px; color: var(--text-gray);">
                        No soldiers found matching your criteria
                    </td>
                </tr>
            `;
        }
    }
    
    // Checkbox selection management
    function attachCheckboxListeners() {
        const rowCheckboxes = document.querySelectorAll('.row-checkbox');
        
        rowCheckboxes.forEach(checkbox => {
            checkbox.addEventListener('change', updateBulkActions);
        });
    }
    
    if (selectAllCheckbox) {
        selectAllCheckbox.addEventListener('change', function(e) {
            const rowCheckboxes = document.querySelectorAll('.row-checkbox');
            rowCheckboxes.forEach(checkbox => {
                checkbox.checked = e.target.checked;
            });
            updateBulkActions();
        });
    }
    
    function updateBulkActions() {
        const checkedBoxes = document.querySelectorAll('.row-checkbox:checked');
        const hasSelection = checkedBoxes.length > 0;
        
        if (bulkExportBtn) bulkExportBtn.disabled = !hasSelection;
        if (bulkNotifyBtn) bulkNotifyBtn.disabled = !hasSelection;
    }
    
    // Bulk actions
    if (bulkExportBtn) {
        bulkExportBtn.addEventListener('click', function() {
            const checkedRows = Array.from(document.querySelectorAll('.row-checkbox:checked'))
                .map(cb => cb.closest('tr'));
            
            console.log('Exporting soldiers:', checkedRows.length);
            alert(`Export functionality: ${checkedRows.length} soldiers selected`);
        });
    }
    
    if (bulkNotifyBtn) {
        bulkNotifyBtn.addEventListener('click', function() {
            const checkedRows = Array.from(document.querySelectorAll('.row-checkbox:checked'))
                .map(cb => cb.closest('tr'));
            
            console.log('Notifying soldiers:', checkedRows.length);
            alert(`Notify functionality: ${checkedRows.length} soldiers will be notified`);
        });
    }
    
    // Initialize
    if (tableBody) {
        initializeSoldiers();
    }
    
    // Stat card click-to-filter functionality
    const statCards = document.querySelectorAll('.stat-card');
    statCards.forEach(card => {
        card.addEventListener('click', function() {
            const label = this.querySelector('.stat-label').textContent.toLowerCase();
            
            if (statusFilter) {
                if (label.includes('ready for deployment')) {
                    statusFilter.value = 'ready';
                } else if (label.includes('medical')) {
                    statusFilter.value = 'not-ready';
                } else if (label.includes('pending')) {
                    statusFilter.value = 'at-risk';
                }
                
                statusFilter.dispatchEvent(new Event('change'));
            }
        });
    });
});
