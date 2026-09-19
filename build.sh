#!/bin/sh
set -e
if [ -z "$THEOS" ]; then
  echo "THEOS is not set. Example: export THEOS=/opt/theos"
  exit 1
fi
make package
echo ""
echo "Built package:"
ls -1 packages/*.deb 2>/dev/null || true
