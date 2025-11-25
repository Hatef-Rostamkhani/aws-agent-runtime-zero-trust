#!/bin/bash
set -e

echo "Testing Task 7: Documentation"

# Check all documentation files exist
DOC_FILES=(
  "../docs/architecture.md"
  "../docs/failure-resilience.md"
  "../docs/security.md"
  "../docs/runbook.md"
  "../docs/setup-guide.md"
  "../docs/api.md"
  "../docs/troubleshooting.md"
  "../docs/performance.md"
)

for file in "${DOC_FILES[@]}"; do
  if [ ! -f "$file" ]; then
    echo "❌ Documentation file missing: $file"
    exit 1
  fi
done
echo "✅ All documentation files present"

# Validate README completeness
if ! grep -q "Setup Guide\|API Documentation\|Architecture" ../README.md; then
  echo "❌ README missing key sections"
  exit 1
fi
echo "✅ README is comprehensive"

# Check setup guide for key commands
if ! grep -q "terraform init\|docker build" ../docs/setup-guide.md; then
  echo "❌ Setup guide missing key commands"
  exit 1
fi
echo "✅ Setup guide includes key commands"

# Check API documentation
if ! grep -q "GET /health\|POST /dispatch" ../docs/api.md; then
  echo "❌ API documentation incomplete"
  exit 1
fi
echo "✅ API documentation complete"

echo ""
echo "🎉 Task 7 Documentation: PASSED"
