# =============================================================================
# Dockerfile — Docker Web Service Management Dashboard
# =============================================================================
# This file contains instructions for Docker to build an image of our app.
# Each instruction creates a "layer" in the image.
#
# Build:  docker build -t docker-web-service:v1 .
# Run:    docker run -d -p 3000:3000 --name my-web docker-web-service:v1
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: Use the official Node.js 20 Alpine base image
# ---------------------------------------------------------------------------
# Why Alpine? It's a minimal Linux distribution (~50 MB vs ~350 MB for full).
# This keeps our image small, fast to download, and more secure.
FROM node:20-alpine

# ---------------------------------------------------------------------------
# Set the working directory inside the container
# ---------------------------------------------------------------------------
# All subsequent commands (COPY, RUN, CMD) will execute relative to /app.
# If /app doesn't exist, Docker creates it automatically.
WORKDIR /app

# ---------------------------------------------------------------------------
# Copy package files first (for better layer caching)
# ---------------------------------------------------------------------------
# Docker caches each layer. By copying package.json first and running
# npm install BEFORE copying our source code, Docker can reuse the
# node_modules layer when only our source code changes.
# This makes rebuilds much faster.
COPY package.json package-lock.json ./

# ---------------------------------------------------------------------------
# Install production dependencies only
# ---------------------------------------------------------------------------
# --omit=dev skips devDependencies (we don't need test tools in production).
# npm ci is faster and more reliable than npm install for CI/CD because it:
#   - Uses the exact versions from package-lock.json
#   - Deletes node_modules before installing (clean state)
RUN npm ci --omit=dev

# ---------------------------------------------------------------------------
# Copy the rest of the application source code
# ---------------------------------------------------------------------------
# This copies everything not excluded by .dockerignore
COPY src/ ./src/
COPY public/ ./public/

# ---------------------------------------------------------------------------
# Create a non-root user for security
# ---------------------------------------------------------------------------
# Running as root inside a container is a security risk.
# If an attacker breaks into the app, they'd have root access to the container.
# We create a dedicated user "appuser" with no password and no home directory.
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Change ownership of the app directory to the new user
RUN chown -R appuser:appgroup /app

# Switch to the non-root user
USER appuser

# ---------------------------------------------------------------------------
# Set environment variables
# ---------------------------------------------------------------------------
# NODE_ENV=production tells Express to enable performance optimizations.
# PORT=3000 sets the default port (can be overridden at runtime).
ENV NODE_ENV=production
ENV PORT=3000

# ---------------------------------------------------------------------------
# Expose the application port
# ---------------------------------------------------------------------------
# EXPOSE is documentation — it tells Docker and other developers which port
# the app listens on. It does NOT actually publish the port.
# You still need -p 3000:3000 when running the container.
EXPOSE 3000

# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------
# Docker will periodically run this command to check if the app is healthy.
# If it fails 3 times in a row, Docker marks the container as "unhealthy".
# wget is available in Alpine (curl is not installed by default).
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

# ---------------------------------------------------------------------------
# Start the application
# ---------------------------------------------------------------------------
# CMD defines the default command that runs when the container starts.
# Using the array form ["node", "src/server.js"] is preferred because:
#   - It runs the process directly (PID 1), not through a shell
#   - This ensures SIGTERM signals are delivered correctly for graceful shutdown
CMD ["node", "src/server.js"]
