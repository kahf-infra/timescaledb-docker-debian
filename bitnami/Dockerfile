FROM pgvector/pgvector:pg16 AS pgvector

# Use a Debian-based TimescaleDB image
FROM timescaledev/timescaledb:2.13.0-pg16 AS timescaledb

FROM bitnami/postgresql-repmgr:16-debian-12

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        build-essential \
        cmake \
        libssl-dev \
        libkrb5-dev \
        postgresql-server-dev-all

RUN git clone --branch 2.13.0 https://github.com/timescale/timescaledb /tmp/timescaledb \
    && cd /tmp/timescaledb \
    && ./bootstrap -DCMAKE_BUILD_TYPE=RelWithDebInfo \
        -DREGRESS_CHECKS=OFF \
        -DTAP_CHECKS=OFF \
        -DGENERATE_DOWNGRADE_SCRIPT=ON \
        -DWARNINGS_AS_ERRORS=OFF \
        -DPROJECT_INSTALL_METHOD="docker" \
    && cd build && make install

RUN apt-get purge -y --auto-remove \
        git \
        build-essential \
        cmake \
        libssl-dev \
        libkrb5-dev \
        postgresql-server-dev-all \
    && rm -rf /var/lib/apt/lists/* /tmp/timescaledb

USER 1001

COPY

# Copy pgvector files
COPY --from=pgvector /usr/lib/postgresql/16/lib/vector.so /opt/bitnami/postgresql/lib/
COPY --from=pgvector /usr/share/postgresql/16/extension/vector* /opt/bitnami/postgresql/share/extension/