FROM ghcr.io/foundry-rs/foundry:nightly AS build

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

# Add jq to get the env variables
RUN apk add jq

# Define the base image with a build arg for the version
ARG APP_TOKEN

# Install dependencies
RUN git config --global url."https://x-access-token:$APP_TOKEN@github.com/".insteadOf "git@github.com:" && \
    forge soldeer install

RUN cd $(find /usr/app/dependencies -maxdepth 1 -type d -name "@smardex-usdn-contracts*" | head -n 1) && \
    forge soldeer install && npm ci

WORKDIR /usr/app/

# Precompile contracts
RUN forge build src script

# Remove possible traces of the token
RUN rm -rf .git

# Start from a clean image
FROM ghcr.io/foundry-rs/foundry:nightly AS fork

# Add bash to foundry image and jq to get the env variables
RUN apk add bash jq

# Add node 20 to foundry image
COPY --from=node:20-alpine /usr/lib /usr/lib
COPY --from=node:20-alpine /usr/local/share /usr/local/share
COPY --from=node:20-alpine /usr/local/lib /usr/local/lib
COPY --from=node:20-alpine /usr/local/include /usr/local/include
COPY --from=node:20-alpine /usr/local/bin /usr/local/bin

# Copy back necessary files
COPY --from=build /usr/app/ /usr/app/

WORKDIR /usr/app/

# Append dump command to deployFork.sh
RUN printf '\necho "$FORK_ENV_DUMP" > .env.fork' >> script/deployFork.sh
