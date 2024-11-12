FROM ghcr.io/foundry-rs/foundry:latest AS build

WORKDIR /usr/app/

# Copy universal-router needed files to /usr/app/
COPY script ./script
COPY src ./src
COPY foundry.toml soldeer.lock \
    package.json package-lock.json \
    ./

# Add node 20 to foundry image
COPY --from=node:20-alpine /usr/lib /usr/lib
COPY --from=node:20-alpine /usr/local/share /usr/local/share
COPY --from=node:20-alpine /usr/local/lib /usr/local/lib
COPY --from=node:20-alpine /usr/local/include /usr/local/include
COPY --from=node:20-alpine /usr/local/bin /usr/local/bin

# Add bash and jq to foundry image
RUN apk add bash jq

# Define the base image with a build arg for the version
ARG APP_TOKEN

# Install dependencies
RUN git config --global url."https://x-access-token:$APP_TOKEN@github.com/".insteadOf "git@github.com:" && \
    forge soldeer install && \
    npm install

# Precompile contracts
RUN forge build src script

# Remove possible traces from private data
RUN rm -rf .git

# Append dump command to deployFork.sh
RUN printf '\necho "$FORK_ENV_DUMP" > .env.fork' >> script/deployFork.sh
