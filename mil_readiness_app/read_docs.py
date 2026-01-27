import zipfile
import re
import sys
import os

def extract_text_from_docx(docx_path):
    try:
        with zipfile.ZipFile(docx_path) as zf:
            xml_content = zf.read('word/document.xml').decode('utf-8')
            # Remove XML tags
            text = re.sub('<[^>]+>', ' ', xml_content)
            # Normalize whitespace
            text = re.sub('\s+', ' ', text).strip()
            return text
    except Exception as e:
        return f"Error reading {docx_path}: {str(e)}"

files = [
    "/Users/ankeetabhandari/development/Project-ATLAS/mil_readiness_app/FORMAL PROCUREMENT MEMO.docx",
    "/Users/ankeetabhandari/development/Project-ATLAS/mil_readiness_app/Military Readiness Application Report.docx"
]

for f in files:
    print(f"--- START OF {os.path.basename(f)} ---")
    print(extract_text_from_docx(f))
    print(f"--- END OF {os.path.basename(f)} ---\n")
