##############
# LITESTREAM #
##############

FROM litestream/litestream:0.3.13 AS litestream

#########
# BUILD #
#########

FROM hexpm/elixir:1.18.1-erlang-27.2-alpine-3.21.0 AS build

# install build dependencies
RUN apk add --no-cache --update git build-base nodejs npm brotli

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

# build project
COPY priv priv
COPY lib lib
RUN mix compile
RUN mix sentry.package_source_code
COPY config/runtime.exs config/

# build assets
COPY assets assets
RUN mix assets.deploy

# build release
RUN mix release

#######
# APP #
#######

FROM alpine:3.21.1 AS app

RUN adduser -S -H -u 999 -G nogroup wakatime

RUN apk add --no-cache --update openssl libgcc libstdc++ ncurses

COPY --from=build /app/_build/prod/rel/w2 /app
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml

RUN mkdir -p /data && chmod ugo+rw -R /data

USER 999
WORKDIR /app
ENV HOME=/app
ENV DATABASE_PATH=/data/w2.db
VOLUME /data
CMD litestream restore -if-db-not-exists -if-replica-exists $DATABASE_PATH && litestream replicate -exec "/app/bin/w2 start"
