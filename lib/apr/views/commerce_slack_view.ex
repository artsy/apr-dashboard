defmodule Apr.Views.CommerceSlackView do
  alias Apr.Views.{
    CommerceTransactionSlackView,
    CommerceOfferSlackView,
    CommerceOrderSlackView,
    CommerceErrorSlackView
  }

  def render(event, routing_key) do
    cond do
      routing_key == "transaction.failure" ->
        CommerceTransactionSlackView.render(event, routing_key)

      routing_key =~ "offer." ->
        CommerceOfferSlackView.render(event, routing_key)

      routing_key =~ "order." ->
        CommerceOrderSlackView.render(event, routing_key)

      routing_key =~ "error." ->
        CommerceErrorSlackView.render(event, routing_key)

      true ->
        nil
    end
  end
end