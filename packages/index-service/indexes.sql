-- ============================================================================
-- Cardano GraphQL Performance Indexes
-- ============================================================================
--
-- This file contains recommended indexes for improving query performance.
-- All indexes use CONCURRENTLY to avoid blocking db-sync writes.
--
-- IMPORTANT: Index creation can take several hours on mainnet (up to 6 hours).
-- Progress can be monitored via: docker compose logs -f index-service
--
-- To enable: Set COMPOSE_PROFILES=token-registry,indexes in your .env file
-- To disable: Remove 'indexes' from COMPOSE_PROFILES
-- ============================================================================

\echo '======================================================================'
\echo 'Starting Cardano GraphQL Index Creation'
\echo '======================================================================'
\echo ''

\echo '[1/2] Creating index on tx_out.address (hash)...'
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tx_out_address ON tx_out USING hash (address);
\echo '✓ Completed: idx_tx_out_address'
\echo ''

\echo '[2/2] Creating index on asset.fingerprint...'
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_asset_fingerprint ON "Asset"(fingerprint);
\echo '✓ Completed: idx_asset_fingerprint'
\echo ''

-- ============================================================================
-- Summary
-- ============================================================================

\echo ''
\echo '======================================================================'
\echo 'Index Creation Complete!'
\echo '======================================================================'
\echo ''
\echo 'All performance indexes have been created successfully.'
\echo 'Your Cardano GraphQL instance should now experience improved query performance.'
\echo ''
\echo 'To verify indexes were created, run:'
\echo '  docker compose exec postgres psql -U <user> -d <db> -c "\\di idx_*"'
\echo ''
\echo 'The index-service container will now exit.'
\echo '======================================================================'
