#!/usr/bin/env python3
"""Fix sleep accumulation bug in home_placeholder.dart"""

filepath = "/Users/mpatel/Projects/AUiX-Project/mil_readiness_app/lib/screens/home_placeholder.dart"

with open(filepath, 'r') as f:
    lines = f.readlines()

# Find and replace lines 113-137
new_lines = lines[:112]  # Keep everything before line 113

# Add the fixed sleep query
new_lines.extend([
    "      // Get LATEST sleep session value (not SUM - prevents accumulation!)\n",
    "      final sleepResults = await db.rawQuery('''\n",
    "        SELECT value FROM health_metrics \n",
    "        WHERE metric_type = 'SLEEP_IN_BED'\n",
    "        AND timestamp >= ?\n",
    "        ORDER BY timestamp DESC \n",
    "        LIMIT 1\n",
    "      ''', [yesterday.millisecondsSinceEpoch]);\n",
    "\n",
    "      print('  😴 Sleep query: ${sleepResults.length} results');\n",
    "      if (sleepResults.isNotEmpty && sleepResults.first['value'] != null) {\n",
    "        print('    Latest sleep session minutes: ${sleepResults.first[\\'value\\']}');\n",
    "      }\n",
    "\n",
    "      if (mounted) {\n",
    "        setState(() {\n",
    "          if (hrResults.isNotEmpty && hrResults.first['value'] != null) {\n",
    "            _heartRate = hrResults.first['value'].toString().split('.')[0];\n",
    "            _lastUpdated = DateTime.fromMillisecondsSinceEpoch(hrResults.first['timestamp'] as int);\n",
    "          }\n",
    "          if (hrvResults.isNotEmpty && hrvResults.first['value'] != null) {\n",
    "            _hrv = hrvResults.first['value'].toString().split('.')[0];\n",
    "          }\n",
    "          if (sleepResults.isNotEmpty && sleepResults.first['value'] != null) {\n",
    "            final hours = (sleepResults.first['value'] as num) / 60.0;\n",
    "            _sleep = hours.toStringAsFixed(1);\n",
    "          }\n",
    "        });\n",
])

# Add everything after line 137
new_lines.extend(lines[136:])

# Write back
with open(filepath, 'w') as f:
    f.writelines(new_lines)

print("✅ Fixed sleep accumulation bug!")
print("   Changed: SELECT SUM(value) → SELECT value (latest only)")
print("   Changed: field['total'] → field['value']")
