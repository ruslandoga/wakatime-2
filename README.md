### WakaTime with SQLite

Successor to [ruslandoga/wakatime-1,](https://github.com/ruslandoga/wakatime-1) this repo contains a single container setup to run a naive clone of [WakaTime server.](https://wakatime.com) It's composed of [SQLite,](https://www.sqlite.org) [Phoenix LiveView,](https://github.com/phoenixframework/phoenix_live_view) and [Litestream.](https://litestream.io)

#### How-to:

```shell
$ git clone https://github.com/ruslandoga/wakatime-2
$ docker build ./wakatime-2 -t wakatime
$ docker run -d \
  --name=w2 \
  --restart unless-stopped \
  -e API_KEY=... \
  -e BACKBLAZE_ACCESS_KEY_ID=... \
  -e BACKBLAZE_BUCKET_NAME=... \
  -e BACKBLAZE_SECRET_ACCESS_KEY=... \
  -e SENTRY_DSN=... \
  -e SECRET_KEY_BASE=... \
  -e PHX_HOST=... \
  -e PHX_SERVER=true \
  -e PORT=9000 \
  -p 9000:9000 \
  -v w2_data:/data \
  wakatime
```
