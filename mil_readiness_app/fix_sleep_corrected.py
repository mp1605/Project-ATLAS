#!/usr/bin/env python3
"""Fix sleep accumulation bug in home_placeholder.dart - CORRECTED"""

filepath = "/Users/mpatel/Projects/AUiX-Project/mil_readiness_app/lib/screens/home_placeholder.dart"

with open(filepath, 'r') as f:
    content = f.read()

# Replace the problematic sleep query section
old_query = """      // Get sleep hours from last 24 hours - try multiple sleep types
      final sleepResults = await db.rawQuery('''
        SELECT SUM(value) as total FROM health_metrics 
        WHERE metric_type LIKE '%SLEEP%'
        AND timestamp >= ?
      ''', [yesterday.millisecondsSinceEpoch]);

      print('  😴 Sleep query: ${sleepResults.length} results');
      if (sleepResults.isNotEmpty && sleepResults.first['total'] != null) {
        print('    Total minutes: ${sleepResults.first['total']}');
      }"""

new_query = """      // Get LATEST sleep session (not SUM - prevents accumulation!)
      final sleepResults = await db.rawQuery('''
        SELECT value FROM health_metrics 
        WHERE metric_type = 'SLEEP_IN_BED'
        AND timestamp >= ?
        ORDER BY timestamp DESC 
        LIMIT 1
      ''', [yesterday.millisecondsSinceEpoch]);

      print('  😴 Sleep query: ${sleepResults.length} results');
      if (sleepResults.isNotEmpty && sleepResults.first['value'] != null) {
        print('    Latest sleep session minutes: ${sleepResults.first['value']}');
      }"""

content = content.replace(old_query, new_query)

# Replace the setState section
old_setstate = """          if (sleepResults.isNotEmpty && sleepResults.first['total'] != null) {
            final hours = (sleepResults.first['total'] as num) / 60.0;
            _sleep = hours.toStringAsFixed(1);
          }"""

new_setstate = """          if (sleepResults.isNotEmpty && sleepResults.first['value'] != null) {
            final hours = (sleepResults.first['value'] as num) / 60.0;
            _sleep = hours.toStringAsFixed(1);
          }"""

content = content.replace(old_setstate, new_setstate)

# Write back
with open(filepath, 'w') as f:
    f.write(content)

print("✅ Fixed sleep accumulation bug!")
print("   Changed: SELECT SUM(value) as total → SELECT value (latest)")
print("   Changed: sleepResults.first['total'] → sleepResults.first['value']")
print("   No escaping issues this time!")
