# STAGE 1: THE FORGE (BUILDER)
FROM alpine:3.19 AS builder

# Install build dependencies for Alpine
# Note: liburing-dev is essential for Postgres 18 AIO
RUN apk add --no-cache \
    build-base \
    curl \
    bison \
    flex \
    liburing-dev \
    openssl-dev \
    zlib-dev \
    perl \
    linux-headers

# WORKDIR /usr/src/postgresql
RUN curl -o pg18.tar.gz https://ftp.postgresql.org/pub/source/v18.0/postgresql-18.0.tar.gz \
    && tar -xzf pg18.tar.gz --strip-components=1

# Optimized for 512MB RAM: Strip unused features
RUN ./configure --prefix=/usr/local/pgsql \
    --with-openssl \
    --with-liburing \
    --without-readline \
    --without-icu \
    CFLAGS="-O2 -march=native"

RUN make -j$(nproc) && make install

# STAGE 2: THE RUNNER (PRODUCTION)
FROM alpine:3.19

# Install only the Alpine runtime libraries
RUN apk add --no-cache \
    liburing \
    openssl \
    zlib \
    musl-locales \
    bash

# Create postgres user and data directory
COPY --from=builder /usr/local/pgsql /usr/local/pgsql
ENV PGDATA=/var/lib/postgresql/data
ENV PATH="/usr/local/pgsql/bin:$PATH"

RUN adduser -D postgres && \
    mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql /usr/local/pgsql

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && chmod +x /usr/local/bin/entrypoint.sh

USER postgres
WORKDIR /var/lib/postgresql
ENTRYPOINT ["entrypoint.sh"]
CMD ["postgres"]