import zipfile
import re
import sys
import os

files = [
    "/Users/ankeetabhandari/development/Project-ATLAS/mil_readiness_app/FORMAL PROCUREMENT MEMO.docx",
    "/Users/ankeetabhandari/development/Project-ATLAS/mil_readiness_app/Military Readiness Application Report.docx"
]

for f in files:
    print(f"\n--- INSPECTING {os.path.basename(f)} ---")
    try:
        with zipfile.ZipFile(f) as zf:
            print("Files in archive:")
            for name in zf.namelist():
                print(f" - {name}")
                
            if 'word/document.xml' in zf.namelist():
                xml_content = zf.read('word/document.xml').decode('utf-8')
                text = re.sub('<[^>]+>', ' ', xml_content)
                text = re.sub('\s+', ' ', text).strip()
                print(f"\nEXTRACTED TEXT:\n{text[:2000]}...") # Print first 2000 chars
            else:
                print("ERROR: word/document.xml not found")
    except Exception as e:
        print(f"Error reading {f}: {str(e)}")
