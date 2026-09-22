import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # Fix the missing `rec` parameter
    content = content.replace("final isService = !r.containsKey('suma_productos');", "final isService = !rec.containsKey('suma_productos');")

    # Fix the label
    label_pattern = r"_selectedTabIndex == 0\s*\?\s*'Total de servicios'\s*:\s*'Total productos'"
    content = re.sub(label_pattern, "'Total'", content)

    with open(file, 'w') as f:
        f.write(content)

