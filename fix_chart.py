import glob
import re

files = glob.glob('lib/screens/*dashboard_screen.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    # 1. Update enum
    content = content.replace("enum _ChartGranularity { daily, monthly, yearly }", "enum _ChartGranularity { individual, daily, monthly, yearly }")

    # 2. Update _granularity getter
    granularity_getter = r"""  _ChartGranularity get _granularity \{
    final diff = _end\.difference\(_start\)\.inDays;
    if \(diff > 730\) return _ChartGranularity\.yearly;
    if \(diff > 90\) return _ChartGranularity\.monthly;
    return _ChartGranularity\.daily;
  \}"""
    new_granularity_getter = """  _ChartGranularity get _granularity {
    if (_activePeriod == _Period.today) return _ChartGranularity.individual;
    final diff = _end.difference(_start).inDays;
    if (diff > 730) return _ChartGranularity.yearly;
    if (diff > 90) return _ChartGranularity.monthly;
    return _ChartGranularity.daily;
  }"""
    content = re.sub(granularity_getter, new_granularity_getter, content)

    # 3. Update _chartDataPoints
    chart_points = r"""  _ChartData _chartDataPoints\(\) \{
    final gran = _granularity;
    switch \(gran\) \{
      case _ChartGranularity\.daily:
        return _groupDaily\(\);"""
    new_chart_points = """  _ChartData _chartDataPoints() {
    final gran = _granularity;
    switch (gran) {
      case _ChartGranularity.individual:
        return _groupIndividual();
      case _ChartGranularity.daily:
        return _groupDaily();"""
    content = re.sub(chart_points, new_chart_points, content)

    # 4. Extract inner logic from _groupDaily and inject _groupIndividual
    # We find _groupDaily block up to "return s;" inside the mapping loop.
    match = re.search(r"  _ChartData _groupDaily\(\) \{[\s\S]*?if \(f\.year == day\.year && f\.month == day\.month && f\.day == day\.day\) \{([\s\S]*?)\}[\s\S]*?\} catch \(_\) \{\}[\s\S]*?return s;", content)
    if match:
        inner_logic = match.group(1).strip()
        # The inner logic calculates 's +=' which we will change to 'values.add' and 'labels.add'
        # But we also have to extract exactly what it computes.
        # It's easier to just calculate it as a variable `pointVal`
        if 's += (serv * 0.50) + ext + prod;' in inner_logic:
            val_logic = inner_logic.replace('s += (serv * 0.50) + ext + prod;', 'values.add((serv * 0.50) + ext + prod);')
        elif 's +=' in inner_logic:
            val_logic = inner_logic.replace('s +=', 'values.add(').replace(';', ');')
        else:
            val_logic = inner_logic + "\n            values.add(s);"

        individual_method = f"""
  _ChartData _groupIndividual() {{
    final sorted = List<Map<String, dynamic>>.from(_records)
      ..sort((a, b) {{
        final fa = a['fecha'] != null ? DateTime.tryParse(a['fecha']) ?? DateTime(2000) : DateTime(2000);
        final fb = b['fecha'] != null ? DateTime.tryParse(b['fecha']) ?? DateTime(2000) : DateTime(2000);
        return fa.compareTo(fb);
      }});
      
    final values = <double>[];
    final labels = <String>[];
    
    for (final r in sorted) {{
      if (r['fecha'] == null) continue;
      try {{
        final f = DateTime.parse(r['fecha']);
        {val_logic}
        labels.add(intl.DateFormat('HH:mm').format(f));
      }} catch (_) {{}}
    }}
    
    if (values.isEmpty) {{
      return _ChartData([0], [''], _ChartGranularity.individual);
    }}
    
    return _ChartData(values, labels, _ChartGranularity.individual);
  }}
"""
        # Inject _groupIndividual before _groupDaily
        content = content.replace("  _ChartData _groupDaily() {", individual_method + "\n  _ChartData _groupDaily() {")

    with open(file, 'w') as f:
        f.write(content)

