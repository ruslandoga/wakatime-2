```console
> docker build . -t w2:local
> mdkir -p data
> cp w2_dev.db* data
> docker run \
  -e DATABASE_PATH=/data/w2_dev.db \
  -e PHX_HOST=localhost \
  -e PHX_SERVER=true \
  -e API_KEY=406fe41f-6d69-4183-a4cc-121e0c524c2b \
  -e SECRET_KEY_BASE=oqVCSPk5goT69U3PIIiuHCLsrh6xwchcmLlw82d8OQhRsaOWU87bEEONUPmKXEGm \
  -v $(PWD)/data:/data \
  -p 4000:4000 \
  -m 256m \
  -ti \
  w2:local bash
```

```console
bash-5.1$ bin/w2 start_iex
Erlang/OTP 25 [erts-13.0] [source] [64-bit] [smp:1:1] [ds:1:1:10] [async-threads:1] [jit]

12:46:37.538 [info] Running W2Web.Endpoint with cowboy 2.9.0 at :::4000 (http)
12:46:37.542 [info] Access W2Web.Endpoint at https://localhost
Interactive Elixir (1.13.4) - press Ctrl+C to exit (type h() ENTER for help)
```

```elixir
iex(w2@afc20a787005)1> W2.Durations.fetch_timeline(0, :os.system_time(:second))
[
  ["w1", 1653738977, 1653739705],
  ["w1", 1653740842, 1653740846],
  ["writer.github.io", 1653820896, 1653822183],
  ["writer.github.io", 1653822761, 1653827800],
  ["writer.github.io", 1653828184, 1653828184],
  ["writer.github.io", 1653830022, 1653830946],
  ["writer.github.io", 1653837221, 1653837221],
  ["writer.github.io", 1654161985, ...],
  ["exqlite", ...],
  [...],
  ...
]
```
