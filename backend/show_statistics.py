"""
Display statistics for generated parking data
"""

import json
from collections import Counter

# Load data
with open('parking_slots_all.json', 'r') as f:
    data = json.load(f)

# Combine all slots
all_slots = []
for city_slots in data.values():
    all_slots.extend(city_slots)

print("=" * 60)
print("Parking Data Statistics")
print("=" * 60)
print()

print(f"Total Slots: {len(all_slots):,}")
print()

print("By City:")
for city, slots in sorted(data.items()):
    print(f"  {city:15s}: {len(slots):,}")
print()

print("By Type:")
types = Counter(s['type'] for s in all_slots)
for t, c in types.most_common():
    percentage = c / len(all_slots) * 100
    print(f"  {t:15s}: {c:,} ({percentage:.1f}%)")
print()

print("By Status:")
statuses = Counter(s['status'] for s in all_slots)
for st, c in statuses.most_common():
    percentage = c / len(all_slots) * 100
    print(f"  {st:15s}: {c:,} ({percentage:.1f}%)")
print()

ev_count = sum(1 for s in all_slots if s["isEVCharging"])
handicap_count = sum(1 for s in all_slots if s["isHandicap"])

print(f"EV Charging Slots: {ev_count:,} ({ev_count/len(all_slots)*100:.1f}%)")
print(f"Handicap Slots: {handicap_count:,} ({handicap_count/len(all_slots)*100:.1f}%)")
print()

avg_price = sum(s["pricePerHour"] for s in all_slots) / len(all_slots)
min_price = min(s["pricePerHour"] for s in all_slots)
max_price = max(s["pricePerHour"] for s in all_slots)

print(f"Average Price/Hour: ₹{avg_price:.2f}")
print(f"Min Price/Hour: ₹{min_price:.2f}")
print(f"Max Price/Hour: ₹{max_price:.2f}")
print()

print("By Area Type:")
area_types = Counter(s['type'] for s in all_slots)
print(f"  Commercial/Street: {sum(c for t, c in area_types.items() if t in ['commercial', 'street']):,}")
print(f"  Residential: {area_types['residential']:,}")
print(f"  Mall: {area_types['mall']:,}")
print(f"  Airport: {area_types['airport']:,}")
print()

print("=" * 60)
