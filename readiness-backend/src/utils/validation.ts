import Joi from 'joi';

/**
 * CRITICAL: This schema REJECTS raw HealthKit data
 * Only calculated/aggregated scores are allowed
 */
export const readinessPayloadSchema = Joi.object({
    user_id: Joi.string().email().required(),
    timestamp: Joi.string().isoDate().required(),
    scores: Joi.object({
        readiness: Joi.number().min(0).max(100).required(),
        fatigue_index: Joi.number().min(0).max(100).required(),
        recovery: Joi.number().min(0).max(100).required(),
        sleep_quality: Joi.number().min(0).max(100).required(),
        sleep_debt: Joi.number().min(0).max(100).required(),
        autonomic_balance: Joi.number().min(0).max(100).required(),
        hrv_deviation: Joi.number().min(0).max(100).required(),
        resting_hr_deviation: Joi.number().min(0).max(100).required(),
        respiratory_stability: Joi.number().min(0).max(100).required(),
        oxygen_stability: Joi.number().min(0).max(100).required(),
        training_load: Joi.number().min(0).max(100).required(),
        acute_chronic_ratio: Joi.number().min(0).max(5).required(),
        cardiovascular_strain: Joi.number().min(0).max(100).required(),
        stress_load: Joi.number().min(0).max(100).required(),
        illness_risk: Joi.number().min(0).max(100).required(),
        overtraining_risk: Joi.number().min(0).max(100).required(),
        energy_availability: Joi.number().min(0).max(100).required(),
        physical_status: Joi.number().min(0).max(100).required(),
    }).required(),
    category: Joi.string().valid('GO', 'CAUTION', 'LIMITED', 'STOP').required(),
    confidence: Joi.string().valid('high', 'medium', 'low').required(),
    metadata: Joi.object({
        data_completeness: Joi.number().min(0).max(100),
        confidence_by_score: Joi.object().pattern(Joi.string(), Joi.string().valid('high', 'medium', 'low')),
    }).optional(),
}).strict().options({
    // STRICT mode - reject unknown fields (prevents raw data leakage)
    abortEarly: false,
    stripUnknown: false // Don't strip - reject instead
});

/**
 * List of FORBIDDEN field names that indicate raw HealthKit data
 */
export const FORBIDDEN_RAW_FIELDS = [
    'heart_rate', 'heart_rate_samples', 'hrv_samples', 'resting_heart_rate',
    'sleep_stages', 'sleep_timestamps', 'sleep_deep_minutes', 'sleep_rem_minutes',
    'steps', 'steps_per_minute', 'step_count',
    'ecg_data', 'ecg_samples',
    'oxygen_measurements', 'spo2_samples',
    'respiratory_samples', 'breathing_rate',
    'gps_coordinates', 'gps_data',
    'nutrition_logs', 'calorie_intake',
    'workout_samples', 'activity_samples',
];

/**
 * Validates that payload doesn't contain raw HealthKit data
 */
export function validateNoRawData(payload: any): { valid: boolean; violations: string[] } {
    const payloadString = JSON.stringify(payload).toLowerCase();
    const violations: string[] = [];

    for (const fieldName of FORBIDDEN_RAW_FIELDS) {
        if (payloadString.includes(fieldName.toLowerCase())) {
            violations.push(fieldName);
        }
    }

    return {
        valid: violations.length === 0,
        violations
    };
}
