#!/usr/bin/env python3
import csv
import json
import sys

# Increase CSV field size limit
maxInt = sys.maxsize
while True:
    try:
        csv.field_size_limit(maxInt)
        break
    except OverflowError:
        maxInt = int(maxInt/10)

def convert_csv_to_json(csv_file):
    with open(csv_file) as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    output_file = csv_file.rsplit('.', 1)[0] + '.json'
    with open(output_file, 'w') as f:
        json.dump(rows, f, indent=2)

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: csv2json.py <csv_file>")
        sys.exit(1)
    convert_csv_to_json(sys.argv[1])

