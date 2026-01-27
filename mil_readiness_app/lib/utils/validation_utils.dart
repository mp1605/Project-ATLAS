import 'dart:math';

class ValidationUtils {
  // Strict Email Regex: RFC 5322 compliant (mostly)
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$",
  );

  // Name Regex: 2-60 chars, letters, spaces, hyphens, apostrophes only
  static final RegExp _nameRegex = RegExp(r"^[a-zA-Z\s\-\']{2,60}$");

  /// Validate Email format
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email is required";
    final normalized = value.trim();
    if (!_emailRegex.hasMatch(normalized)) return "Enter a valid email (e.g., name@domain.com)";
    return null;
  }

  /// Validate Password strength (12+ characters, broad enough but safe)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";
    if (value.length < 12) return "Password must be at least 12 characters";
    
    // Check for common weak patterns (basic check)
    final weakPatterns = ['password', '123456789', 'qwertyuiop'];
    if (weakPatterns.any((p) => value.toLowerCase().contains(p))) {
      return "Choose a more secure password";
    }
    return null;
  }

  /// Validate Name (length and characters)
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Name is required";
    if (!_nameRegex.hasMatch(value.trim())) {
      return "Enter a valid name (2-60 chars, no symbols or emojis)";
    }
    return null;
  }

  /// Validate Weight (Medically plausible: 20-300 kg)
  static String? validateWeight(String? value, {bool isMetric = true}) {
    if (value == null || value.trim().isEmpty) return "Weight is required";
    final n = double.tryParse(value.trim());
    if (n == null) return "Enter a numeric value";
    
    if (isMetric) {
      if (n < 20 || n > 300) return "Enter a valid weight (20-300 kg)";
    } else {
      if (n < 44 || n > 660) return "Enter a valid weight (44-660 lbs)";
    }
    return null;
  }

  /// Validate Height (Medically plausible: 100-250 cm)
  static String? validateHeight(String? value, {bool isMetric = true}) {
    if (value == null || value.trim().isEmpty) return "Height is required";
    final n = double.tryParse(value.trim());
    if (n == null) return "Enter a numeric value";
    
    if (isMetric) {
      if (n < 100 || n > 250) return "Enter a valid height (100-250 cm)";
    } else {
      // FT/IN logic usually handled by a different picker, but if raw inches:
      if (n < 39 || n > 98) return "Enter a valid height (approx 3'3\" - 8'2\")";
    }
    return null;
  }

  /// Validate Age (17-90)
  static String? validateAge(String? value) {
    if (value == null || value.trim().isEmpty) return "Age is required";
    final n = int.tryParse(value.trim());
    if (n == null) return "Enter a numeric age";
    if (n < 17 || n > 90) return "Age must be between 17 and 90";
    return null;
  }

  /// Validate Sleep Duration (0-18 hours)
  static String? validateSleepDuration(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final n = double.tryParse(value.trim());
    if (n == null) return "Numeric only";
    if (n < 0 || n > 18) return "Enter 0-18 hours";
    return null;
  }

  /// Validate Activity Duration (1-600 minutes)
  static String? validateActivityDuration(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final n = int.tryParse(value.trim());
    if (n == null) return "Numeric only";
    if (n < 1 || n > 600) return "Enter 1-600 minutes";
    return null;
  }

  /// Normalize and trim input
  static String normalize(String? value) => (value ?? "").trim();
  
  /// Normalize email for storage
  static String normalizeEmail(String? value) => (value ?? "").trim().toLowerCase();
  
  /// Validate RPE (Rate of Perceived Exertion) scale (1-10)
  static String? validateRPE(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final n = int.tryParse(value.trim());
    if (n == null) return "Numeric only";
    if (n < 1 || n > 10) return "Enter 1-10";
    return null;
  }
  
  /// Validate daily step count (0-100,000 steps)
  static String? validateSteps(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final n = int.tryParse(value.trim());
    if (n == null) return "Numeric only";
    if (n < 0 || n > 100000) return "Enter 0-100,000 steps";
    return null;
  }
  
  /// Validate distance in meters (0-100 km)
  static String? validateDistance(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final n = double.tryParse(value.trim());
    if (n == null) return "Numeric only";
    if (n < 0 || n > 100000) return "Enter 0-100 km";
    return null;
  }
  
  /// Validate calories burned (0-5000 kcal)
  static String? validateCalories(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    final n = int.tryParse(value.trim());
    if (n == null) return "Numeric only";
    if (n < 0 || n > 5000) return "Enter 0-5,000 kcal";
    return null;
  }
  
  /// Validate sleep time ordering (wake must be after bedtime)
  static String? validateSleepTimeOrdering(DateTime bedtime, DateTime waketime) {
    if (waketime.isBefore(bedtime)) {
      return 'Wake time must be after bedtime';
    }
    
    final duration = waketime.difference(bedtime);
    if (duration.inHours > 18) {
      return 'Sleep duration cannot exceed 18 hours';
    }
    
    return null;
  }
  
  /// Validate password confirmation
  static String? validatePasswordConfirmation(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  }
}
