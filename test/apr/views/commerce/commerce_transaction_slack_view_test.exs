defmodule Apr.Views.CommerceTransactionSlackViewTest do
  use ExUnit.Case, async: true
  alias Apr.Views.CommerceTransactionSlackView
  alias Apr.Subscriptions.Subscription
  import Mox

  @subscription %Subscription{}
  @fraud_theme_subscription %Subscription{theme: "fraud"}

  setup do
    expect(Apr.PaymentsMock, :payment_info, fn _, _ ->
      {:ok,
       %{
         card_country: "XY",
         zip_check: true,
         cvc_check: true,
         charge_data: %{risk_level: "high", liability_shift: true},
         billing_state: "NY"
       }}
    end)

    :ok
  end

  test "adds shipping details for orders to be shipped" do
    event =
      Apr.Fixtures.commerce_transaction_event(%{
        "id" => "order123",
        "items_total_cents" => 2_000_000,
        "currency_code" => "USD",
        "seller_id" => "partner1",
        "seller_type" => "gallery",
        "buyer_id" => "user1",
        "buyer_type" => "user",
        "fulfillment_type" => "ship",
        "shipping_country" => "US",
        "shipping_name" => "Art",
        "mode" => "buy"
      })

    slack_view = CommerceTransactionSlackView.render(@subscription, event, "transaction.failed")
    titles = slack_view.attachments |> Enum.flat_map(fn a -> a.fields end) |> Enum.map(fn field -> field.title end)
    assert "buy / ship" in titles
    assert "CVC Check  :x:" in titles
    assert "ZIP Check  :x:" in titles
    assert "Liability Shift :verified:" in titles
    assert "Shipping Name" in titles
    assert "Shipping Country" in titles
    assert "Shipping State" in titles
  end

  test "Has correct fields for pickup orders" do
    event =
      Apr.Fixtures.commerce_transaction_event(%{
        "id" => "order123",
        "items_total_cents" => 2_000_000,
        "currency_code" => "USD",
        "seller_id" => "partner1",
        "seller_type" => "gallery",
        "buyer_id" => "user1",
        "buyer_type" => "user",
        "fulfillment_type" => "pickup",
        "mode" => "buy"
      })

    slack_view = CommerceTransactionSlackView.render(@subscription, event, "transaction.failed")
    titles = slack_view.attachments |> Enum.flat_map(fn a -> a.fields end) |> Enum.map(fn field -> field.title end)
    assert "buy / pickup" in titles
    assert "CVC Check  :x:" in titles
    assert "ZIP Check  :x:" in titles
    assert "Liability Shift :verified:" in titles
    assert "Shipping Name" not in titles
    assert "Shipping Country" not in titles
    assert "Shipping State" not in titles
  end

  test "doesn't add shipping details for orders without a fulfillment type" do
    event =
      Apr.Fixtures.commerce_transaction_event(%{
        "id" => "order123",
        "items_total_cents" => 2_000_000,
        "currency_code" => "USD",
        "seller_id" => "partner1",
        "seller_type" => "gallery",
        "buyer_id" => "user1",
        "buyer_type" => "user"
      })

    slack_view = CommerceTransactionSlackView.render(@subscription, event, "transaction.failed")
    titles = Enum.map(List.first(slack_view.attachments).fields, fn field -> field.title end)
    assert "Fulfillment Type" not in titles
    assert "Shipping Country" not in titles
    assert "Shipping Name" not in titles
  end

  test "returns nil for subscription with fraud template and total cents below threshodl" do
    event =
      Apr.Fixtures.commerce_transaction_event(%{
        "id" => "order123",
        "items_total_cents" => 2000_00,
        "currency_code" => "USD",
        "seller_id" => "partner1",
        "seller_type" => "gallery",
        "buyer_id" => "user1",
        "buyer_type" => "user"
      })

    slack_view = CommerceTransactionSlackView.render(@fraud_theme_subscription, event, "transaction.failed")
    assert is_nil(slack_view)
  end

  test "returns message for subscription with fraud template and total cents below threshodl" do
    event =
      Apr.Fixtures.commerce_transaction_event(%{
        "id" => "order123",
        "items_total_cents" => 3001_00,
        "currency_code" => "USD",
        "seller_id" => "partner1",
        "seller_type" => "gallery",
        "buyer_id" => "user1",
        "buyer_type" => "user"
      })

    slack_view = CommerceTransactionSlackView.render(@fraud_theme_subscription, event, "transaction.failed")
    refute is_nil(slack_view.text)
  end
end
