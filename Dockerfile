# Build stage
FROM swift:6.1 AS builder

WORKDIR /app

# Copy package files
COPY Package.swift ./
COPY Sources ./Sources
COPY Tests ./Tests

# Build the project
RUN swift build -c release

# Run tests
RUN swift test

# Runtime stage
FROM swift:6.1-slim

WORKDIR /app

# Copy built binary
COPY --from=builder /app/.build/release/starcraft-cli /usr/local/bin/

# Set environment variable for API token (to be provided at runtime)
ENV PANDA_TOKEN=""

# Create a non-root user
RUN useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app

USER appuser

# Default command
CMD ["starcraft-cli", "test"]