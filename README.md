### WakaTime with SQLite

Successor to [ruslandoga/wakatime-1,](https://github.com/ruslandoga/wakatime-1) this repo contains a single container setup to run a naive clone of [WakaTime server.](https://wakatime.com) It's composed of [SQLite,](https://www.sqlite.org) [Phoenix LiveView,](https://github.com/phoenixframework/phoenix_live_view) and [Litestream.](https://litestream.io)

#### How-to:

```shell
$ git clone https://github.com/ruslandoga/wakatime-2
$ docker build ./wakatime-2 -t wakatime

$ api_key=$(uuidgen | tr '[:upper:]' '[:lower:]')
# 7d35a1b6-df99-4961-8590-2c4bd40f1a77

$ secret_key_base=$(openssl rand -base64 48)
# UUKYZcUCnAYdULnYRwu/auAJCG/Av0X22iwEaSVjSMD+o8YsSjjYGNZuvrVAp/8j

$ docker run -d \
  --name=w2 \
  --restart unless-stopped \
  -e "API_KEY=$api_key" \
  -e "S3_BUCKET_NAME=wakatime-2" \
  -e "S3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" \
  -e "S3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" \
  -e "SENTRY_DSN=https://e23dd06d7bff44f18d86f3387867891@019635.ingest.sentry.io/6173453" \
  -e "SECRET_KEY_BASE=$secret_key_base" \
  -e "PHX_HOST=stats.copycat.fun" \
  -e "PHX_SERVER=true" \
  -e "PORT=9000" \
  -p 9000:9000 \
  -v w2_data:/data \
  wakatime
```
