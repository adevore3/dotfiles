#!/bin/bash

assert_equals() {
    if [ "$1" = "$2" ]; then
        echo "✓ $3"
    else
        echo "✗ $3"
        echo "  Expected: $1"
        echo "  Got: $2"
        exit 1
    fi
}

assert_contains() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$actual" == *"$expected"* ]]; then
        echo "✓ $message"
    else
        echo "✗ $message"
        echo "  Expected to contain: $expected"
        echo "  Got: $actual"
        exit 1
    fi
}

export -f assert_equals
export -f assert_contains

