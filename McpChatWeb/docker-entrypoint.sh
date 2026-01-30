#!/bin/bash
# =============================================================================
# McpChatWeb Docker Entrypoint Script
# Handles initialization and startup of the web portal
# =============================================================================

set -e

echo "🚀 Starting COBOL Migration Demo Portal..."

# Data directories
DATA_DIR="/app/Data"
OUTPUT_DIR="/app/output"
SEED_DATA_DIR="/app/seed-data"

# Check if this is the first run (no existing database in mounted volume)
if [ ! -f "$DATA_DIR/migration.db" ]; then
    echo "📦 First run detected - initializing demo data..."
    
    # Copy seed data if available
    if [ -f "$SEED_DATA_DIR/migration.db" ]; then
        echo "  → Copying seed migration database..."
        cp "$SEED_DATA_DIR/migration.db" "$DATA_DIR/migration.db"
    fi
    
    # Copy seed output files if available
    if [ -d "$SEED_DATA_DIR/output" ] && [ "$(ls -A $SEED_DATA_DIR/output 2>/dev/null)" ]; then
        echo "  → Copying seed output files..."
        cp -r "$SEED_DATA_DIR/output/"* "$OUTPUT_DIR/" 2>/dev/null || true
    fi
    
    echo "✅ Demo data initialized"
else
    echo "✅ Existing data found - using mounted volume"
fi

# Wait for Neo4j to be ready (if enabled)
# Note: In Azure Container Apps, the app will handle connection retries internally
if [ "${ApplicationSettings__Neo4j__Enabled}" = "true" ]; then
    NEO4J_URI="${ApplicationSettings__Neo4j__Uri:-bolt://neo4j:7687}"
    echo "ℹ️  Neo4j configured at: $NEO4J_URI"
    echo "ℹ️  Application will connect to Neo4j on startup (with internal retries)"
    # Give Neo4j a few seconds to start
    sleep 5
fi

echo ""
echo "=========================================="
echo "  COBOL Migration Demo Portal"
echo "=========================================="
echo "  Port: 5028"
echo "  Environment: ${ASPNETCORE_ENVIRONMENT:-Production}"
echo "  Neo4j Enabled: ${ApplicationSettings__Neo4j__Enabled:-true}"
echo "=========================================="
echo ""

# Start the application
exec dotnet McpChatWeb.dll
