##############
# LITESTREAM #
##############

FROM litestream/litestream:0.3.8 AS litestream

#######
# ZIG #
#######

FROM alpine:3.15.4 as zig

ARG ZIGVER=0.10.0-dev.2473+e498fb155
WORKDIR /deps

RUN apk add --no-cache --update curl xz

RUN curl https://ziglang.org/builds/zig-linux-$(uname -m)-$ZIGVER.tar.xz -O
RUN tar -xf zig-linux-$(uname -m)-$ZIGVER.tar.xz
RUN mv zig-linux-$(uname -m)-$ZIGVER/ local/
RUN rm zig-linux-$(uname -m)-$ZIGVER.tar.xz

#########
# BUILD #
#########

FROM hexpm/elixir:1.13.4-erlang-25.0-alpine-3.15.4 as build

# install build dependencies
RUN apk add --no-cache --update git build-base nodejs npm

# prepare build dir
RUN mkdir /app
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get
RUN mix deps.compile

# build sqlite extension
COPY sqlite_ext sqlite_ext
COPY --from=zig /deps/local /deps/local
RUN ln -s /deps/local/zig /usr/bin/

# build project
COPY priv priv
COPY lib lib
COPY Makefile Makefile
RUN make timeline
RUN mix sentry_recompile
COPY config/runtime.exs config/

# build assets
COPY assets assets
RUN mix assets.deploy

# build release
RUN mix release

#######
# APP #
#######

FROM alpine:3.15.4 AS app
RUN apk add --no-cache --update bash openssl libgcc libstdc++

WORKDIR /app

RUN chown nobody:nobody /app
USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/w2 ./
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml

ENV HOME=/app

CMD litestream restore -if-db-not-exists -if-replica-exists $DATABASE_PATH && litestream replicate -exec "/app/bin/w2 start"
