/**
 * Radial Progress Component
 * Circular progress indicators with animations
 */

class RadialProgress {
    constructor(container, options = {}) {
        this.container = container;
        this.options = {
            size: options.size || 200,
            strokeWidth: options.strokeWidth || 18,
            value: options.value || 0,
            maxValue: options.maxValue || 100,
            color: options.color || '#06b6d4',
            backgroundColor: options.backgroundColor || '#0f172a',
            duration: options.duration || 1500,
            label: options.label || '',
            showValue: options.showValue !== false,
            glowEffect: options.glowEffect !== false,
            ...options
        };

        this.currentValue = 0;
        this.targetValue = this.options.value;
        this.init();
    }

    init() {
        this.render();
        this.animate();
    }

    render() {
        const { size, strokeWidth, backgroundColor, label, showValue } = this.options;
        const center = size / 2;
        const radius = (size - strokeWidth) / 2;
        const circumference = 2 * Math.PI * radius;

        this.container.innerHTML = `
            <div class="radial-progress-wrapper" style="width: ${size}px; height: ${size}px; position: relative;">
                <svg width="${size}" height="${size}" class="radial-progress-svg">
                    <!-- Background circle -->
                    <circle
                        cx="${center}"
                        cy="${center}"
                        r="${radius}"
                        fill="none"
                        stroke="${backgroundColor}"
                        stroke-width="${strokeWidth}"
                    />
                    <!-- Progress circle -->
                    <circle
                        class="radial-progress-circle"
                        cx="${center}"
                        cy="${center}"
                        r="${radius}"
                        fill="none"
                        stroke="${this.getColor()}"
                        stroke-width="${strokeWidth}"
                        stroke-dasharray="${circumference}"
                        stroke-dashoffset="${circumference}"
                        stroke-linecap="round"
                        transform="rotate(-90 ${center} ${center})"
                        style="transition: stroke-dashoffset ${this.options.duration}ms ease-out, stroke ${this.options.duration / 2}ms ease;"
                    />
                </svg>
                ${showValue ? `
                    <div class="radial-progress-center" style="
                        position: absolute;
                        top: 50%;
                        left: 50%;
                        transform: translate(-50%, -50%);
                        text-align: center;
                    ">
                        <div class="radial-progress-value" style="
                            font-size: ${size * 0.25}px;
                            font-weight: 700;
                            color: #f8fafc;
                            line-height: 1;
                        ">0</div>
                        ${label ? `<div class="radial-progress-label" style="
                            font-size: ${size * 0.08}px;
                            color: #94a3b8;
                            text-transform: uppercase;
                            letter-spacing: 1px;
                            margin-top: ${size * 0.05}px;
                        ">${label}</div>` : ''}
                    </div>
                ` : ''}
            </div>
        `;

        this.circle = this.container.querySelector('.radial-progress-circle');
        this.valueElement = this.container.querySelector('.radial-progress-value');
        this.circumference = circumference;

        // Add glow effect
        if (this.options.glowEffect) {
            this.circle.style.filter = `drop-shadow(0 0 8px ${this.getColor()}40)`;
        }
    }

    getColor() {
        if (this.options.color) return this.options.color;

        // Auto color based on value
        const percentage = (this.targetValue / this.options.maxValue) * 100;
        if (percentage >= 80) return '#10b981'; // Green
        if (percentage >= 60) return '#f59e0b'; // Orange
        return '#ef4444'; // Red
    }

    animate() {
        const { duration, maxValue } = this.options;
        const targetOffset = this.circumference - (this.targetValue / maxValue) * this.circumference;

        // Animate circle
        setTimeout(() => {
            this.circle.style.strokeDashoffset = targetOffset;
            this.circle.style.stroke = this.getColor();
        }, 100);

        // Animate number
        if (this.valueElement) {
            const startTime = Date.now();
            const animate = () => {
                const elapsed = Date.now() - startTime;
                const progress = Math.min(elapsed / duration, 1);
                const eased = this.easeOutCubic(progress);
                const current = Math.round(eased * this.targetValue);

                this.valueElement.textContent = current;
                this.currentValue = current;

                if (progress < 1) {
                    requestAnimationFrame(animate);
                }
            };
            requestAnimationFrame(animate);
        }
    }

    easeOutCubic(t) {
        return 1 - Math.pow(1 - t, 3);
    }

    setValue(newValue) {
        this.targetValue = Math.max(0, Math.min(newValue, this.options.maxValue));
        this.animate();
    }

    destroy() {
        this.container.innerHTML = '';
    }
}

// Initialize radial progress on page load
document.addEventListener('DOMContentLoaded', () => {
    // Example: Initialize all elements with data-radial-progress
    document.querySelectorAll('[data-radial-progress]').forEach(el => {
        const value = parseFloat(el.dataset.value || 0);
        const label = el.dataset.label || '';
        const color = el.dataset.color || null;
        const size = parseFloat(el.dataset.size || 200);

        new RadialProgress(el, {
            value,
            label,
            color,
            size
        });
    });
});

// Export for use in other scripts
if (typeof module !== 'undefined' && module.exports) {
    module.exports = RadialProgress;
}
