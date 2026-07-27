import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

/// Generates a unique ID for password entries
String generateId() => uuid.v4();

/// Shows a simple snackbar message
void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Formats a DateTime to a readable string
String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
