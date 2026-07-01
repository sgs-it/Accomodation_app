import pandas as pd

# Read the excel file
excel_path = r'c:\Users\HP\Downloads\Staff_app\Updated staff accomodation.xlsx'
df = pd.read_excel(excel_path, sheet_name='Sheet2')

# Start building the markdown file
md_content = "# Updated Staff Credentials\n\n"
md_content += "Here are the updated login credentials for all staff members based on the new bed assignments.\n\n"
md_content += "> [!TIP]\n> Staff can log in using their **Occupant ID** as the username. The app will automatically convert it to the correct email format (e.g. `1234@staff.sgs.com`). The password is their **Bed ID**.\n\n"

md_content += "| Occupant Name | Username (Occupant ID) | Password (Bed ID) | Location |\n"
md_content += "|---------------|------------------------|-------------------|----------|\n"

# Add rows
for idx, row in df.iterrows():
    name = str(row.get('Occupant Name', '')).strip()
    occ_id = str(row.get('Occupant ID', '')).strip()
    bed_id = str(row.get('Bed ID', '')).strip()
    location = str(row.get('Location', '')).strip()
    
    if occ_id and occ_id != 'nan':
        md_content += f"| {name} | `{occ_id}` | `{bed_id}` | {location} |\n"

# Write to artifact directory
artifact_path = r'C:\Users\HP\.gemini\antigravity-ide\brain\e522d1da-f402-4b98-a20a-5558dda5690e\updated_staff_credentials.md'
with open(artifact_path, 'w', encoding='utf-8') as f:
    f.write(md_content)

print(f"Artifact created at {artifact_path}")
