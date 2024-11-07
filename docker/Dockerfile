FROM ghcr.io/foundry-rs/foundry:latest AS dev

WORKDIR /usr/app/

# Copy universal-router needed files to /usr/app/
COPY script ./script
COPY src ./src
COPY foundry.toml soldeer.lock \
    package.json package-lock.json \
    ./

# ARG SSH_KEY

# # Setting up a new GitHub SSH access
# RUN sed -i '/github/d' /root/.ssh/known_hosts

# # Define a static path for the SSH key
# RUN touch "/root/.ssh/github_key"
# RUN echo $SSH_KEY > "/root/.ssh/github_key"
# RUN chmod 600 "/root/.ssh/github_key"

# # Update the SSH config to use this key for GitHub
# RUN mkdir -p ~/.ssh && \
#     echo "Host github.com" >> ~/.ssh/config && \
#     echo "Hostname github.com" >> ~/.ssh/config && \
#     echo "IdentityFile=/root/.ssh/github_key" >> ~/.ssh/config

# # Add GitHub's SSH key to known_hosts for trusted connection
# RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

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
# ENV USDN_CONTRACTS="https://x-access-token:$APP_TOKEN@github.com/SmarDex-Ecosystem/usdn-contracts.git"

# Replace the dependency with the one from the build arg
# RUN sed -i '/source = "git@github.com:SmarDex-Ecosystem\/usdn-contracts.git"/c\'"source = \"$USDN_CONTRACTS\"" soldeer.lock

# ENV USDN_CONTRACTS=""

# Install dependencies
RUN git config --global url."https://x-access-token:$APP_TOKEN@github.com/".insteadOf "git@github.com:" && \
    forge soldeer install && \
    npm install

# Precompile contracts
RUN forge build src script

# Remove trace from app token
# RUN sed -i '/x-access-token/d' soldeer.lock

RUN rm -dr .git

# # Remove any trace of the ssh key
# RUN rm -f /root/.ssh/github_key
# RUN sed -i '/^Host github.com$/,/^$/d' ~/.ssh/config
# RUN sed -i '/github.com/d' /root/.ssh/known_hosts

# Append dump command to deployFork.sh
RUN printf '\necho "$FORK_ENV_DUMP" > .env.fork' >> script/deployFork.sh
