/**
 * Animated Score Cards
 * Micro-animations for stat cards with count-up effects
 */

class ScoreCard {
    constructor(element) {
        this.element = element;
        this.valueElement = element.querySelector('[data-count]');
        if (this.valueElement) {
            this.targetValue = parseFloat(this.valueElement.dataset.count || this.valueElement.textContent);
            this.currentValue = 0;
            this.duration = parseFloat(this.valueElement.dataset.duration || 1500);
            this.decimals = parseInt(this.valueElement.dataset.decimals || 0);
        }
    }

    animate() {
        if (!this.valueElement) return;

        const startTime = Date.now();
        const animate = () => {
            const elapsed = Date.now() - startTime;
            const progress = Math.min(elapsed / this.duration, 1);
            const eased = this.easeOutCubic(progress);
            const current = eased * this.targetValue;

            this.valueElement.textContent = current.toFixed(this.decimals);
            this.currentValue = current;

            if (progress < 1) {
                requestAnimationFrame(animate);
            } else {
                // Add completion effect
                this.element.classList.add('count-complete');
            }
        };

        requestAnimationFrame(animate);
    }

    easeOutCubic(t) {
        return 1 - Math.pow(1 - t, 3);
    }
}

/**
 * Animated Stats Grid
 * Manages multiple score cards with staggered animations
 */
class AnimatedStatsGrid {
    constructor(container, options = {}) {
        this.container = container;
        this.options = {
            staggerDelay: options.staggerDelay || 100,
            ...options
        };
        this.cards = [];
        this.init();
    }

    init() {
        const cards = this.container.querySelectorAll('[data-score-card]');
        cards.forEach((card, index) => {
            const scoreCard = new ScoreCard(card);
            this.cards.push(scoreCard);

            // Stagger animations
            setTimeout(() => {
                card.classList.add('animate-fadeInScale');
                setTimeout(() => scoreCard.animate(), 200);
            }, index * this.options.staggerDelay);
        });
    }

    refresh(data) {
        // Update card values with new data
        this.cards.forEach((card, index) => {
            if (data[index] !== undefined) {
                card.targetValue = data[index];
                card.animate();
            }
        });
    }
}

/**
 * Pulse Icon Effect
 * Adds pulsing animation to icons
 */
function addIconPulse(iconElement, color = '#06b6d4') {
    if (!iconElement) return;

    iconElement.style.animation = 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite';
    iconElement.style.filter = `drop-shadow(0 0 4px ${color}40)`;
}

/**
 * Trend Indicator
 * Shows up/down arrows with animation
 */
function createTrendIndicator(value, previousValue) {
    const diff = value - previousValue;
    const percentage = previousValue !== 0 ? ((diff / previousValue) * 100).toFixed(1) : 0;
    const isPositive = diff > 0;
    const arrow = isPositive ? '▲' : '▼';
    const color = isPositive ? '#10b981' : '#ef4444';

    return `
        <span class="trend-indicator animate-fadeIn" style="
            color: ${color};
            font-size: 0.85em;
            font-weight: 600;
            margin-left: 8px;
        ">
            ${arrow} ${Math.abs(percentage)}%
        </span>
    `;
}

/**
 * Auto-initialize on page load
 */
document.addEventListener('DOMContentLoaded', () => {
    // Initialize all stat grids
    document.querySelectorAll('[data-animated-stats]').forEach(grid => {
        new AnimatedStatsGrid(grid);
    });

    // Add hover effects to score cards
    document.querySelectorAll('[data-score-card]').forEach(card => {
        card.addEventListener('mouseenter', () => {
            card.style.transform = 'translateY(-4px)';
            card.style.boxShadow = '0 12px 24px rgba(0, 0, 0, 0.3)';
        });

        card.addEventListener('mouseleave', () => {
            card.style.transform = 'translateY(0)';
            card.style.boxShadow = '';
        });
    });

    // Add pulse effect to icons
    document.querySelectorAll('[data-pulse-icon]').forEach(icon => {
        const color = icon.dataset.pulseColor || '#06b6d4';
        addIconPulse(icon, color);
    });
});

// Export for use in other scripts
if (typeof window !== 'undefined') {
    window.ScoreCard = ScoreCard;
    window.AnimatedStatsGrid = AnimatedStatsGrid;
    window.createTrendIndicator = createTrendIndicator;
    window.addIconPulse = addIconPulse;
}
