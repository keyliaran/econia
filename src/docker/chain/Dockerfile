# Aptos CLI git metadata.
ARG GIT_REPO=https://github.com/aptos-labs/aptos-core.git
ARG GIT_TAG=aptos-cli-v2.0.3

# Relative to Econia repository root.
ARG MOVE_ROOT=src/move
ARG ECONIA_ROOT=$MOVE_ROOT/econia
ARG FAUCET_ROOT=$MOVE_ROOT/faucet
ARG ACCOUNT_FILES=src/docker/chain/accounts/

# Relative to image root.
ARG NODE_BIN=/aptos-core/target/cli/aptos

# Get Aptos repo and build dependencies, then compile.
FROM rust:1-bookworm AS compile-cli
ARG GIT_REPO
ARG GIT_TAG
ARG NODE_BIN
RUN git clone \
    $GIT_REPO \
    --branch $GIT_TAG \
    --depth 1
RUN apt-get update && apt-get install -y \
    build-essential \
    libclang-dev \
    libpq-dev \
    libssl-dev \
    lld \
    && rm -rf /var/lib/apt/lists/*
RUN RUSTFLAGS="--cfg tokio_unstable" cargo build \
    --bin aptos \
    --manifest-path aptos-core/Cargo.toml \
    --package aptos \
    --profile cli
RUN strip -s $NODE_BIN

# Copy over combiled CLI binary only and get runtime dependency.
FROM debian:bookworm-slim AS run-cli
ARG NODE_BIN
COPY --from=compile-cli $NODE_BIN /usr/local/bin
RUN apt-get update && apt-get install -y \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Publish Econia and Econia faucet to local testnet.
FROM run-cli as publish-packages

# Copy in Move and account files.
ARG MOVE_ROOT
ARG ECONIA_ROOT
ARG FAUCET_ROOT
ARG ACCOUNT_FILES
WORKDIR /app/
COPY $ECONIA_ROOT/Move.toml econia/
COPY $ECONIA_ROOT/sources/* econia/sources/
COPY $FAUCET_ROOT/Move.toml faucet/
COPY $FAUCET_ROOT/sources/* faucet/sources/
COPY $ACCOUNT_FILES accounts/

# Get git, start a local testnet, initialize profiles, publish packages.
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*
RUN aptos node run-local-testnet \
        --test-dir data \
        --with-faucet \
        & \
    sleep 30 && \
    aptos init \
        --network local \
        --private-key-file accounts/econia.key \
        --profile econia \
        && \
    aptos move publish \
        --assume-yes \
        --included-artifacts none \
        --named-addresses econia=$(cat accounts/econia.address) \
        --override-size-check \
        --package-dir econia \
        --profile econia \
        && \
    aptos init \
        --network local \
        --private-key-file accounts/faucet.key \
        --profile faucet \
        && \
    aptos move publish \
        --assume-yes \
        --included-artifacts none \
        --named-addresses econia_faucet=$(cat accounts/faucet.address) \
        --override-size-check \
        --package-dir faucet \
        --profile faucet

# Copy over chain data to fresh CLI, expose REST API and Aptos Faucet API.
FROM run-cli as run
COPY --from=publish-packages /app/data /app/data
EXPOSE 8080
EXPOSE 8081

# Serve local testnet.
ENTRYPOINT [ \
    "usr/local/bin/aptos", "node", "run-local-testnet", \
    "--test-dir", "/app/data", \
    "--with-faucet" \
]
