import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Revert all to r.
    content = content.replace("!rec.containsKey", "!r.containsKey")

    # Fix only inside _showDetails
    # The signature is void _showDetails(Map<String, dynamic> rec) {
    # So we can replace !r. with !rec. just for that method
    
    parts = content.split('void _showDetails(Map<String, dynamic> rec) {')
    if len(parts) == 2:
        method_and_rest = parts[1]
        method_parts = method_and_rest.split('  }', 1)
        
        # In method_parts[0], replace !r. with !rec.
        fixed_method = method_parts[0].replace("!r.containsKey", "!rec.containsKey")
        
        new_content = parts[0] + 'void _showDetails(Map<String, dynamic> rec) {' + fixed_method + '  }' + method_parts[1]
        content = new_content
    
    with open(file, 'w') as f:
        f.write(content)

