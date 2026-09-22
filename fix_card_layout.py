import glob
import re

files = glob.glob('lib/screens/*.dart')

for file in files:
    with open(file, 'r') as f:
        content = f.read()

    if '_buildCard' not in content and '_buildRecordCard' not in content:
        continue

    # Regex to match the Row containing sucursal and itemLabel inside _buildCard / _buildRecordCard
    # Pattern looks for Row( children: [ if (sucursal.isNotEmpty) ... [ ... ] Text(itemLabel ... ) ] )
    
    # We will do a string replacement for the common pattern in finanzas_filtered_records_screen.dart and dashboards
    old_patterns = [
        # Pattern 1 with Flexible
        """                  Row(
                    children: [
                      if (sucursal.isNotEmpty) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(6)),
                            child: Text(sucursal, overflow: TextOverflow.ellipsis, maxLines: 1, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(itemLabel, style: TextStyle(
                        fontSize: 11,
                        color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black38,
                        fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                      )),
                    ],
                  ),""",
        # Pattern 2 without Flexible
        """                  Row(
                    children: [
                      if (sucursal.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(6)),
                          child: Text(sucursal, style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w500)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(itemLabel, style: TextStyle(
                        fontSize: 11,
                        color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black38,
                        fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                      )),
                    ],
                  ),""",
        # Pattern 3 with multi-line formatted code
        """                  Row(
                    children: [
                      if (sucursal.isNotEmpty) ...[
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              sucursal,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        itemLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black38,
                          fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),""",
        # Pattern 4 formatted without Flexible
        """                  Row(
                    children: [
                      if (sucursal.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sucursal,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        itemLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black38,
                          fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),"""
    ]

    new_code = """                  Text(
                    sucursal.isNotEmpty ? '$sucursal · $itemLabel' : itemLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isGasto ? Colors.red.withValues(alpha: 0.7) : Colors.black45,
                      fontWeight: isGasto ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),"""

    modified = False
    for pat in old_patterns:
        if pat in content:
            content = content.replace(pat, new_code)
            modified = True

    if modified:
        with open(file, 'w') as f:
            f.write(content)
        print(f"Updated {file}")

