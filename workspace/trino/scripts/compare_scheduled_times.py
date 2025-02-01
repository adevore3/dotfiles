#!/usr/bin/env python3
import json
import sys
import math
from collections import defaultdict

def load_json_by_index(filename):
    with open(filename) as f:
        data = json.load(f)
        return {item['queryIndex']: item['totalScheduledMillis'] for item in data}

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} file1.json file2.json")
        sys.exit(1)

    file1_data = load_json_by_index(sys.argv[1])
    file2_data = load_json_by_index(sys.argv[2])

    # Calculate ratios for matching queryIndexes
    ratios = []
    problematic = []
    for idx in sorted(set(file1_data.keys()) & set(file2_data.keys())):
        if file2_data[idx] != 0:  # Avoid division by zero
            ratio = file1_data[idx] / file2_data[idx]
            if ratio <= 0:  # Log domain includes only positive numbers
                problematic.append((idx, ratio, file1_data[idx], file2_data[idx]))
            else:
                ratios.append(ratio)

    if not ratios:
        print("No valid ratios found")
        sys.exit(1)

    print(f"Found {len(ratios)} valid ratios")
    if problematic:
        print(f"\nFound {len(problematic)} problematic ratios:")
        for idx, ratio, num, den in problematic:
            print(f"Query {idx}: {ratio} ({num} / {den})")

    print("\nFirst 10 valid ratios (queryIndex: ratio):")
    count = 0
    indexes = sorted(set(file1_data.keys()) & set(file2_data.keys()))
    for idx in indexes:
        if file2_data[idx] != 0 and count < 10:
            ratio = file1_data[idx] / file2_data[idx]
            if ratio > 0:
                print(f"Query {idx}: {ratio:.4f} ({file1_data[idx]} / {file2_data[idx]})")
                count += 1

    # Calculate geometric mean
    try:
        log_sum = sum(math.log(r) for r in ratios)
        geomean = math.exp(log_sum / len(ratios))
        print(f"\nGeometric mean of ratios: {geomean:.4f}")
        
        # Additional statistics
        min_ratio = min(ratios)
        max_ratio = max(ratios)
        print(f"Min ratio: {min_ratio:.4f}")
        print(f"Max ratio: {max_ratio:.4f}")
        print(f"Number of ratios < 1: {sum(1 for r in ratios if r < 1)}")
        print(f"Number of ratios > 1: {sum(1 for r in ratios if r > 1)}")
    except ValueError as e:
        print(f"\nError calculating geometric mean: {e}")
        print("Distribution of ratios:")
        for r in sorted(ratios):
            print(f"{r:.4f}")

if __name__ == "__main__":
    main()
