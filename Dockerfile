FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG OPENCLAW_DOCKER_APT_PACKAGES=""
RUN if [ -n "$OPENCLAW_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $OPENCLAW_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN OPENCLAW_A2UI_SKIP_MISSING=1 pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV OPENCLAW_PREFER_PNPM=1
RUN pnpm ui:build

ENV NODE_ENV=production

# Security hardening: Run as non-root user
# The node:22-bookworm image includes a 'node' user (uid 1000)
# This reduces the attack surface by preventing container escape via root privileges

# Create config directory and minimal config for the node user
# Use .openclaw (new path) and create symlink from legacy .clawdbot
RUN mkdir -p /home/node/.openclaw && \
    echo 'gateway:' > /home/node/.openclaw/config.yaml && \
    echo '  mode: local' >> /home/node/.openclaw/config.yaml && \
    ln -s /home/node/.openclaw /home/node/.clawdbot && \
    chown -R node:node /home/node/.openclaw /home/node/.clawdbot

USER node
ENV HOME=/home/node

CMD ["node", "dist/index.js", "gateway", "run", "--port", "8080", "--auth", "token"]
