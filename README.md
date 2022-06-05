### WakaTime with SQLite

Successor to [ruslandoga/wakatime-1,](https://github.com/ruslandoga/wakatime-1) this repo contains a single container setup to run a bootleg of [WakaTime.](https://wakatime.com) It's composed of [SQLite,](https://www.sqlite.org) [Phoenix LiveView,](https://github.com/phoenixframework/phoenix_live_view) and [Litestream.](https://litestream.io) It can be deployed to a free instance on [fly.io.](https://fly.io)

#### How-to:

```sh
> git clone https://github.com/ruslandoga/wakatime-1

> api_key=$(uuidgen | tr '[:upper:]' '[:lower:]')

> fly create
> fly secrets set API_KEY=${api_key}
> vim fly.toml ........ TODO
> fly deploy

> cat > ~/.wakatime.cfg << EOM
[settings]
api_url = https://your-app.fly.dev
api_key = ${api_key}
EOM
```
