defmodule W2.Sentry.FinchHTTPClient do
  @moduledoc false
  # adapts https://github.com/getsentry/sentry-elixir/blob/master/lib/sentry/hackney_client.ex
  @behaviour Sentry.HTTPClient
  @finch W2.Sentry.Finch

  @impl true
  def child_spec do
    Supervisor.child_spec({Finch, name: @finch}, [])
  end

  @impl true
  def post(url, headers, body) do
    req = Finch.build(:post, url, headers, body)

    case Finch.request(req, @finch, receive_timeout: 5000) do
      {:ok, %Finch.Response{status: status, body: body, headers: headers}} ->
        {:ok, status, headers, body}

      {:error, _reason} = failure ->
        failure
    end
  end
end
