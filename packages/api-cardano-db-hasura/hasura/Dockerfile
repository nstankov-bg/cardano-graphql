FROM hasura/graphql-engine:v2.17.1.cli-migrations-v2
COPY docker-entrypoint.sh /bin/
ENV \
  POSTGRES_HOST=postgres \
  POSTGRES_PORT=5432 \
  POSTGRES_DB_FILE=/run/secrets/postgres_db \
  POSTGRES_PASSWORD_FILE=/run/secrets/postgres_password \
  POSTGRES_USER_FILE=/run/secrets/postgres_user \
  HASURA_GRAPHQL_ENABLED_LOG_TYPES="startup, http-log, webhook-log, websocket-log" \
  HASURA_GRAPHQL_ENABLE_TELEMETRY=false \
  HASURA_GRAPHQL_STRINGIFY_NUMERIC_TYPES=true
EXPOSE 8080
