##############
# LITESTREAM #
##############

FROM litestream/litestream:0.3.13 AS litestream

#########
# BUILD #
#########

FROM hexpm/elixir:1.17.1-erlang-27.0-alpine-3.20.0 as build

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

FROM alpine:3.19.1 AS app
RUN apk add --no-cache --update openssl libgcc libstdc++ ncurses

WORKDIR /app

RUN chown nobody:nobody /app
USER nobody:nobody

COPY --from=build --chown=nobody:nobody /app/_build/prod/rel/w2 ./
COPY --from=litestream /usr/local/bin/litestream /usr/local/bin/litestream
COPY litestream.yml /etc/litestream.yml

ENV HOME=/app

CMD litestream restore -if-db-not-exists -if-replica-exists $DATABASE_PATH && litestream replicate -exec "/app/bin/w2 start"
