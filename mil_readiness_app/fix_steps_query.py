#!/usr/bin/env python3
"""Fix missing steps query - CORRECTED VERSION"""

filepath = "/Users/mpatel/Projects/AUiX-Project/mil_readiness_app/lib/screens/home_placeholder.dart"

with open(filepath, 'r') as f:
    lines = f.readlines()

# Find where to insert the steps query (after sleep query ends)
insert_line = None
for i, line in enumerate(lines):
    if "Total sleep minutes (DEEP+REM+LIGHT)" in line:
        # Find the closing brace of the if statement (next line with just "      }")
        for j in range(i+1, len(lines)):
            if lines[j].strip() == '}':
                insert_line = j + 1
                break
        break

if insert_line:
    # Insert the steps query
    steps_query_lines = [
        '\n',
        '      // Get total steps from last 24 hours\n',
        "      final stepsResults = await db.rawQuery('''\n",
        "        SELECT SUM(value) as total FROM health_metrics \n",
        "        WHERE metric_type = 'STEPS'\n",
        "        AND timestamp >= ?\n",
        "      ''', [yesterday.millisecondsSinceEpoch]);\n",
        '\n',
        "      print('  👟 Steps query: ${stepsResults.length} results');\n",
        "      if (stepsResults.isNotEmpty && stepsResults.first['total'] != null) {\n",
        "        print('    Total steps: ${stepsResults.first['total']}');\n",
        "      }\n",
    ]
    
    # Insert at the found position
    lines = lines[:insert_line] + steps_query_lines + lines[insert_line:]
    
    # Write back
    with open(filepath, 'w') as f:
        f.writelines(lines)
    
    print("✅ Successfully added steps query!")
    print(f"   Inserted at line {insert_line}")
else:
    print("❌ Could not find insertion point")
