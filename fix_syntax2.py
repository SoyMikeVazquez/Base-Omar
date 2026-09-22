import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # The error is that the first container is missing its closing parenthesis and comma.
    # It looks like:
    #             ],
    #           ),
    #         const SizedBox(height: 16),
    #         Container(
    
    error_pattern = """            ],
          ),
        const SizedBox(height: 16),
        Container("""
    
    fixed_pattern = """            ],
          ),
        ),
        const SizedBox(height: 16),
        Container("""
        
    if error_pattern in content:
        content = content.replace(error_pattern, fixed_pattern)
        with open(file, 'w') as f:
            f.write(content)

