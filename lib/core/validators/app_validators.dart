/// Centralized input validation helpers for all forms.
class AppValidators {
  const AppValidators._();

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final _phoneRegex = RegExp(r'^[+]?[0-9]{10,15}$');

  static final _nameRegex = RegExp(r"^[a-zA-Z\s'-]{2,50}$");

  static final _otpRegex = RegExp(r'^[0-9]{4,6}$');

  /// Validates an email address.
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates a phone number (10-15 digits, optional + prefix).
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    if (!_phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  /// Validates a full name (2-50 chars, letters/spaces/hyphens/apostrophes).
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (!_nameRegex.hasMatch(value.trim())) {
      return 'Enter a valid name (2-50 characters)';
    }
    return null;
  }

  /// Validates an OTP code (4-6 digits).
  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required';
    }
    if (!_otpRegex.hasMatch(value.trim())) {
      return 'Enter a valid OTP code';
    }
    return null;
  }

  /// Validates a required text field with optional min/max length.
  static String? required(
    String? value, {
    String fieldName = 'This field',
    int minLength = 1,
    int? maxLength,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    if (value.trim().length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (maxLength != null && value.trim().length > maxLength) {
      return '$fieldName must be at most $maxLength characters';
    }
    return null;
  }

  /// Validates a password (min 8 chars, at least one letter and one number).
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[a-zA-Z]').hasMatch(value)) {
      return 'Password must contain at least one letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  /// Validates a description with optional min/max length.
  static String? description(
    String? value, {
    int minLength = 10,
    int maxLength = 1000,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < minLength) {
      return 'Description must be at least $minLength characters';
    }
    if (value.trim().length > maxLength) {
      return 'Description must be at most $maxLength characters';
    }
    return null;
  }

  /// Validates optional min/max price filters (INR).
  static String? priceRange({double? min, double? max}) {
    if (min != null && min < 0) {
      return 'Minimum price cannot be negative';
    }
    if (max != null && max < 0) {
      return 'Maximum price cannot be negative';
    }
    if (min != null && max != null && min > max) {
      return 'Minimum price cannot exceed maximum';
    }
    return null;
  }

  /// Validates a subject/title with optional min/max length.
  static String? subject(
    String? value, {
    int minLength = 3,
    int maxLength = 100,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Subject is required';
    }
    if (value.trim().length < minLength) {
      return 'Subject must be at least $minLength characters';
    }
    if (value.trim().length > maxLength) {
      return 'Subject must be at most $maxLength characters';
    }
    return null;
  }

  /// Validates a positive integer (e.g. capacity).
  static String? positiveInt(
    String? value, {
    String fieldName = 'Value',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final n = int.tryParse(value.trim());
    if (n == null || n <= 0) {
      return 'Enter a valid $fieldName';
    }
    return null;
  }

  /// Validates a non-negative price amount.
  static String? nonNegativePrice(
    String? value, {
    String fieldName = 'Price',
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final n = double.tryParse(value.trim());
    if (n == null || n < 0) {
      return 'Enter a valid $fieldName';
    }
    return null;
  }
}
