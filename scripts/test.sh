#!/bin/bash

echo "🧪 Running Stark Insured Tests..."

# Check if snforge is installed
if ! command -v snforge &> /dev/null; then
    echo "❌ snforge is not installed. Please install Starknet Foundry."
    exit 1
fi

# Run tests with coverage
echo "🔍 Running tests with coverage..."
snforge test --coverage

if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed!"
    exit 1
fi

# Generate detailed coverage report
echo "📊 Generating coverage report..."
snforge test --coverage --coverage-report lcov

echo "🎉 Testing completed!"
