import glob

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    error_pattern = """            ],
          ),
        ),
        ),
      ],
    );"""
    
    fixed_pattern = """            ],
          ),
        ),
      ],
    );"""
        
    if error_pattern in content:
        content = content.replace(error_pattern, fixed_pattern)
        with open(file, 'w') as f:
            f.write(content)

