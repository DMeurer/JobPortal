#!/bin/bash
# Fix permissions for docker-entrypoint.sh files

echo "Setting execute permissions on entrypoint scripts..."

chmod +x Backend/docker-entrypoint.sh 2>/dev/null && echo "✓ Backend/docker-entrypoint.sh" || echo "✗ Backend/docker-entrypoint.sh not found"
chmod +x Runners/docker-entrypoint.sh 2>/dev/null && echo "✓ Runners/docker-entrypoint.sh" || echo "✗ Runners/docker-entrypoint.sh not found"
chmod +x Frontend/docker-entrypoint.sh 2>/dev/null && echo "✓ Frontend/docker-entrypoint.sh" || echo "✗ Frontend/docker-entrypoint.sh not found"

echo ""
echo "Done! Now rebuild with: docker-compose build"
