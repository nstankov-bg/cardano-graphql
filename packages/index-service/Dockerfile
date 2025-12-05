FROM postgres:15-alpine

# Install postgresql-client (psql)
RUN apk add --no-cache postgresql-client bash

# Create app directory
WORKDIR /app

# Copy SQL file and entrypoint script
COPY indexes.sql /app/indexes.sql
COPY entrypoint.sh /app/entrypoint.sh

# Make entrypoint executable
RUN chmod +x /app/entrypoint.sh

# Run the entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
