FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies
COPY package.json bun.lockb* ./
RUN bun install --frozen-lockfile || bun install

# Copy source
COPY . .

# Create data directory
RUN mkdir -p /app/data

# Run
EXPOSE 3000
CMD ["bun", "run", "src/index.ts"]
