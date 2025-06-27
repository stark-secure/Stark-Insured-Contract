FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    pkg-config \
    libssl-dev \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Cairo
RUN curl -L https://github.com/starkware-libs/cairo/releases/download/v2.4.0/cairo-lang-2.4.0-x86_64-unknown-linux-gnu.tar.gz | tar -xz -C /usr/local
ENV PATH="/usr/local/cairo-lang-2.4.0/bin:${PATH}"

# Install Scarb
RUN curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

# Install Starknet Foundry
RUN curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
ENV PATH="/root/.foundry/bin:${PATH}"

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Build the project
RUN scarb build

# Default command
CMD ["bash"]
