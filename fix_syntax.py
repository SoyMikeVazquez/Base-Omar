import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Fix the double parenthesis syntax error
    content = content.replace("?? 0.0));", "?? 0.0);")

    # 2. Add individual case to switch(chartData.granularity)
    switch_granularity = r"""    switch \(chartData\.granularity\) \{
      case _ChartGranularity\.daily:"""
    new_switch = """    switch (chartData.granularity) {
      case _ChartGranularity.individual:
        granLabel = 'Vista individual';
        break;
      case _ChartGranularity.daily:"""
    content = re.sub(switch_granularity, new_switch, content)

    with open(file, 'w') as f:
        f.write(content)

