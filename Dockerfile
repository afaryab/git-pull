FROM alpine:latest

# Install git and openssh-client for SSH support
RUN apk add --no-cache git openssh-client bash

# Create a non-root user
RUN addgroup -g 1000 gituser && \
    adduser -D -u 1000 -G gituser gituser

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set default work directory
WORKDIR /work

# Run as non-root user by default
# Note: Override with --user root if you need UID_GID ownership change
USER gituser

ENTRYPOINT ["/entrypoint.sh"]
