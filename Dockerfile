ARG PG_VERSION=16
############################
# Build tools binaries in separate image
############################
ARG GO_VERSION=1.22.4
FROM golang:${GO_VERSION}-bookworm AS tools

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        gcc \
        libc6-dev \
    && rm -rf /var/lib/apt/lists/* \
    && go install github.com/timescale/timescaledb-tune/cmd/timescaledb-tune@latest \
    && go install github.com/timescale/timescaledb-parallel-copy/cmd/timescaledb-parallel-copy@latest

############################
# Grab old versions from previous version
############################
ARG PG_VERSION=16
ARG TS_VERSION=2.13.0
FROM postgres:${PG_VERSION}-bookworm AS oldversions

# Verify and rebuild if coming from Alpine
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        libkrb5-dev \
        cmake \
        postgresql-server-dev-16 \
        git \
        libssl-dev \
        ca-certificates
RUN  git clone --branch 2.13.0 https://github.com/timescale/timescaledb /tmp/rebuild \
     && cd /tmp/rebuild \
     && ./bootstrap -DCMAKE_BUILD_TYPE=RelWithDebInfo \
     && cd build && make install

############################
# Main image build
############################
FROM postgres:${PG_VERSION}-bookworm

LABEL maintainer="Timescale https://www.timescale.com"

ARG PG_MAJOR_VERSION=16
ARG PGVECTOR_VERSION=v0.7.0
ARG CLANG_VERSION=14
ARG OSS_ONLY
ARG TS_VERSION=2.13.0

# Install base dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        postgresql-plpython3-${PG_MAJOR_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Install pgvector
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        postgresql-server-dev-${PG_MAJOR_VERSION} \
        git \
        build-essential \
        clang-${CLANG_VERSION} \
        llvm-${CLANG_VERSION}-dev \
        llvm-${CLANG_VERSION} \
    && git clone --branch ${PGVECTOR_VERSION} https://github.com/pgvector/pgvector.git /tmp/pgvector \
    && cd /tmp/pgvector \
    && make \
    && make install \
    && apt-get purge -y --auto-remove \
        postgresql-server-dev-${PG_MAJOR_VERSION} \
        git \
        build-essential \
        clang-${CLANG_VERSION} \
        llvm-${CLANG_VERSION}-dev \
        llvm-${CLANG_VERSION} \
    && rm -rf /var/lib/apt/lists/* /tmp/pgvector

# Copy components
COPY docker-entrypoint-initdb.d/* /docker-entrypoint-initdb.d/
COPY --from=tools /go/bin/* /usr/local/bin/
COPY --from=oldversions /usr/lib/postgresql/${PG_MAJOR_VERSION}/lib/timescaledb-*.so /usr/local/lib/postgresql/
COPY --from=oldversions /usr/share/postgresql/${PG_MAJOR_VERSION}/extension/timescaledb--*.sql /usr/local/share/postgresql/extension/

# Build TimescaleDB
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        cmake \
        libssl-dev \
        libkrb5-dev \
        postgresql-server-dev-${PG_MAJOR_VERSION} \
    && git clone --branch ${TS_VERSION} https://github.com/timescale/timescaledb /tmp/timescaledb \
    && cd /tmp/timescaledb \
    && ./bootstrap -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DREGRESS_CHECKS=OFF \
        -DTAP_CHECKS=OFF \
        -DGENERATE_DOWNGRADE_SCRIPT=ON \
        -DWARNINGS_AS_ERRORS=OFF \
        -DPROJECT_INSTALL_METHOD="docker"${OSS_ONLY} \
    && cd build && make install \
    && if [ -n "${OSS_ONLY}" ]; then \
        rm -f $(pg_config --pkglibdir)/timescaledb-tsl-*.so; \
    fi \
    && apt-get purge -y --auto-remove \
        git \
        build-essential \
        cmake \
        libssl-dev \
        libkrb5-dev \
        postgresql-server-dev-${PG_MAJOR_VERSION} \
    && rm -rf /var/lib/apt/lists/* /tmp/timescaledb

# Final configuration
RUN sed -i -r "s/^#?(shared_preload_libraries)\s*=\s*'(.*)'/\1 = 'timescaledb,\2'/" \
    /usr/share/postgresql/postgresql.conf.sample && \
    sed -i -r "s/,'//" /usr/share/postgresql/postgresql.conf.sample