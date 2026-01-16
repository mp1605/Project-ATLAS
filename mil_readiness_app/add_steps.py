#!/usr/bin/env python3
"""Add steps display to home screen"""

filepath = "/Users/mpatel/Projects/AUiX-Project/mil_readiness_app/lib/screens/home_placeholder.dart"

with open(filepath, 'r') as f:
    content = f.read()

# 1. Add steps variable
content = content.replace(
    "  String _sleep = '--';\n  DateTime? _lastUpdated;",
    "  String _sleep = '--';\n  String _steps = '--';\n  DateTime? _lastUpdated;"
)

# 2. Add steps query (after sleep query)
steps_query = """
      // Get total steps from last 24 hours
      final stepsResults = await db.rawQuery('''
        SELECT SUM(value) as total FROM health_metrics 
        WHERE metric_type = 'STEPS'
        AND timestamp >= ?
      ''', [yesterday.millisecondsSinceEpoch]);

      print('  👟 Steps query: ${stepsResults.length} results');
      if (stepsResults.isNotEmpty && stepsResults.first['total'] != null) {
        print('    Total steps: ${stepsResults.first['total']}');
      }
"""

# Find the position after sleep query print statement
sleep_print_end = content.find("print('    Total sleep minutes (DEEP+REM+LIGHT): ${sleepResults.first['total']}');")
if sleep_print_end != -1:
    # Find the end of that print statement (next newline + spaces)
    insert_pos = content.find('\n', sleep_print_end) + 1
    # Find the next line's indentation
    next_line_start = insert_pos
    while content[next_line_start] == ' ':
        next_line_start += 1
    
    content = content[:insert_pos] + steps_query + content[insert_pos:]

# 3. Add steps to setState
content = content.replace(
    "          if (sleepResults.isNotEmpty && sleepResults.first['total'] != null) {\n            final hours = (sleepResults.first['total'] as num) / 60.0;\n            _sleep = hours.toStringAsFixed(1);\n          }\n        });\n        print('  ✅ Stats updated: HR=$_heartRate, HRV=$_hrv, Sleep=$_sleep');",
    "          if (sleepResults.isNotEmpty && sleepResults.first['total'] != null) {\n            final hours = (sleepResults.first['total'] as num) / 60.0;\n            _sleep = hours.toStringAsFixed(1);\n          }\n          if (stepsResults.isNotEmpty && stepsResults.first['total'] != null) {\n            _steps = (stepsResults.first['total'] as num).toInt().toString();\n          }\n        });\n        print('  ✅ Stats updated: HR=$_heartRate, HRV=$_hrv, Sleep=$_sleep, Steps=$_steps');"
)

# Write back
with open(filepath, 'w') as f:
    f.write(content)

print("✅ Added steps tracking to home screen!")
print("   - Added _steps variable")
print("   - Added steps query")
print("   - Added steps to setState and logging")
print("\n⚠️  Still need to update UI manually to show 4 cards instead of 3")
print("   Change _buildQuickStatsRow() to show 2x2 grid with Steps card")
