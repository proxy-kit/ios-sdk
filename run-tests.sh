#!/bin/bash

# ProxyKit iOS SDK Test Runner

echo "🧪 Running ProxyKit iOS SDK Tests..."
echo "=================================="

# Clean build directory
echo "🧹 Cleaning build artifacts..."
swift package clean

# Build the package
echo "🔨 Building package..."
swift build

# Run tests
echo "🏃 Running tests..."
swift test --parallel

# Check test results
if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed!"
    exit 1
fi
