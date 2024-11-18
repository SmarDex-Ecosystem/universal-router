FROM node:20-alpine AS build

WORKDIR /usr/app/

# Copy universal-router needed files to /usr/app/
COPY script ./script
COPY src ./src
COPY foundry.toml soldeer.lock \
    package.json package-lock.json \
    ./

# Add bash and jq to foundry image
RUN apk add bash jq

# Install bash
RUN apk add --no-cache bash

# Define the base image with a build arg for the version
ARG APP_TOKEN

# Install foundry
RUN wget -L https://foundry.paradigm.xyz | bash

# Install dependencies
RUN git config --global url."https://x-access-token:$APP_TOKEN@github.com/".insteadOf "git@github.com:" && \
    forge soldeer install

WORKDIR /usr/app/dependencies/@smardex-usdn-contracts-0.22.0
RUN forge soldeer install && npm ci
WORKDIR /usr/app/

# Precompile contracts
RUN forge build src script

###
# Remove possible traces of the token
###
RUN rm -rf .git

# Start from a clean image
FROM node:20-alpine AS fork

# Install foundry
RUN curl -L https://foundry.paradigm.xyz | bash

COPY --from=build /usr/app/ /usr/app/

###
###

WORKDIR /usr/app/

# Append dump command to deployFork.sh
RUN printf '\necho "$FORK_ENV_DUMP" > .env.fork' >> script/deployFork.sh
