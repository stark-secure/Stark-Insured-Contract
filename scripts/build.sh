#!/bin/bash

echo "🔨 Building Stark Insured Contracts..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
scarb clean

# Build all contracts
echo "📦 Building contracts..."
scarb build

if [ $? -eq 0 ]; then
    echo "✅ Build completed successfully!"
    echo "📊 Contract sizes:"
    find target/dev -name "*.sierra.json" -exec wc -c {} + | sort -n
else
    echo "❌ Build failed!"
    exit 1
fi

echo "🎉 Build process completed!"
