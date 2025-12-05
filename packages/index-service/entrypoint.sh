#!/bin/bash
set -e

# ============================================================================
# Cardano GraphQL Index Service
# ============================================================================
# This script creates performance indexes on the cardano-db-sync database.
# It waits for the database to be ready, then applies indexes concurrently.
# ============================================================================

# Read database credentials from secrets
if [ -f "$POSTGRES_DB_FILE" ]; then
  export POSTGRES_DB=$(cat "$POSTGRES_DB_FILE")
fi

if [ -f "$POSTGRES_USER_FILE" ]; then
  export POSTGRES_USER=$(cat "$POSTGRES_USER_FILE")
fi

if [ -f "$POSTGRES_PASSWORD_FILE" ]; then
  export POSTGRES_PASSWORD=$(cat "$POSTGRES_PASSWORD_FILE")
fi

# Validate required environment variables
if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_PORT" ] || [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ]; then
  echo "ERROR: Missing required database configuration"
  echo "Required: POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD"
  exit 1
fi

# Connection string
export PGPASSWORD="$POSTGRES_PASSWORD"
PSQL_CMD="psql -h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DB"

echo "======================================================================"
echo "Cardano GraphQL Index Service"
echo "======================================================================"
echo "Database: $POSTGRES_HOST:$POSTGRES_PORT/$POSTGRES_DB"
echo "User: $POSTGRES_USER"
echo "======================================================================"
echo ""

# Wait for database to be ready
echo "Waiting for database to be ready..."
MAX_RETRIES=60
RETRY_COUNT=0

while ! $PSQL_CMD -c "SELECT 1" > /dev/null 2>&1; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "ERROR: Database did not become ready within $MAX_RETRIES attempts"
    exit 1
  fi
  echo "Database not ready yet (attempt $RETRY_COUNT/$MAX_RETRIES)... waiting 5 seconds"
  sleep 5
done

echo "✓ Database is ready!"
echo ""

# Check if db-sync schema is initialized
echo "Checking if cardano-db-sync schema is initialized..."
TABLE_COUNT=$($PSQL_CMD -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('block', 'tx', 'tx_out')" | xargs)

if [ "$TABLE_COUNT" != "3" ]; then
  echo "WARNING: cardano-db-sync schema does not appear to be fully initialized"
  echo "Found $TABLE_COUNT/3 expected tables (block, tx, tx_out)"
  echo ""
  echo "The index service will wait for db-sync to initialize..."

  # Wait for schema to be ready
  while [ "$TABLE_COUNT" != "3" ]; do
    sleep 30
    TABLE_COUNT=$($PSQL_CMD -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('block', 'tx', 'tx_out')" | xargs)
    echo "Still waiting for schema initialization... ($TABLE_COUNT/3 tables found)"
  done
fi

echo "✓ Schema is initialized!"
echo ""

# Optional: Wait for minimum data before creating indexes
if [ -n "$MIN_BLOCK_COUNT" ]; then
  echo "Waiting for at least $MIN_BLOCK_COUNT blocks to be synced..."
  BLOCK_COUNT=$($PSQL_CMD -t -c "SELECT COUNT(*) FROM block" | xargs)

  while [ "$BLOCK_COUNT" -lt "$MIN_BLOCK_COUNT" ]; do
    echo "Current block count: $BLOCK_COUNT (waiting for $MIN_BLOCK_COUNT)..."
    sleep 60
    BLOCK_COUNT=$($PSQL_CMD -t -c "SELECT COUNT(*) FROM block" | xargs)
  done

  echo "✓ Minimum block count reached: $BLOCK_COUNT"
  echo ""
fi

# Apply indexes
echo "======================================================================"
echo "Starting index creation process"
echo "======================================================================"
echo ""
echo "NOTE: This process can take several hours on mainnet."
echo "      Index creation uses CONCURRENTLY to avoid blocking db-sync."
echo "      You can monitor progress with: docker compose logs -f index-service"
echo ""

START_TIME=$(date +%s)

# Run the SQL file
if $PSQL_CMD -f /app/indexes.sql; then
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  HOURS=$((DURATION / 3600))
  MINUTES=$(((DURATION % 3600) / 60))
  SECONDS=$((DURATION % 60))

  echo ""
  echo "======================================================================"
  echo "SUCCESS: All indexes created successfully!"
  echo "======================================================================"
  echo "Total time: ${HOURS}h ${MINUTES}m ${SECONDS}s"
  echo ""
  echo "The index-service container will now exit."
  echo "You can verify indexes with:"
  echo "  docker compose exec postgres psql -U $POSTGRES_USER -d $POSTGRES_DB -c \"\\di idx_*\""
  echo "======================================================================"
  exit 0
else
  echo ""
  echo "======================================================================"
  echo "ERROR: Index creation failed!"
  echo "======================================================================"
  echo ""
  echo "This could be due to:"
  echo "  - Insufficient disk space"
  echo "  - Database permissions issues"
  echo "  - Concurrent index creation failure (rare)"
  echo ""
  echo "Check the logs above for specific error messages."
  echo "You can retry by restarting the service:"
  echo "  docker compose restart index-service"
  echo "======================================================================"
  exit 1
fi
