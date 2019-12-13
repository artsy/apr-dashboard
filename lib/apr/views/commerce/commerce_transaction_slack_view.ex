defmodule Apr.Views.CommerceTransactionSlackView do
  import Apr.Views.Helper
  alias Apr.Views.CommerceHelper

  alias Apr.Subscriptions.{
    Subscription
  }

  @payments Application.get_env(:apr, :payments)

  def render(
        %Subscription{theme: "fraud"},
        %{"properties" => %{"order" => %{"items_total_cents" => items_total_cents}}},
        _routing_key
      )
      when items_total_cents < 3000_00,
      do: nil

  def render(_, event, _routing_key) do
    order = event["properties"]["order"]
    seller = CommerceHelper.fetch_participant_info(order["seller_id"], order["seller_type"])
    buyer = CommerceHelper.fetch_participant_info(order["buyer_id"], order["buyer_type"])

    attachments =
      []
      |> append_order_info(order)
      |> append_participant_info(buyer, seller)
      |> append_transaction_info(event)

    %{
      text: ":alert:",
      attachments: attachments,
      unfurl_links: true
    }
  end

  defp append_participant_info(attachments, buyer, seller) do
    attachments ++
      [
        %{
          color: "#ED553B",
          author_name: cleanup_name(buyer["name"]),
          author_link: artsy_admin_user_link(buyer["_id"]),
          title: seller["name"],
          title_link: exchange_partner_orders_link(seller["_id"]),
          fields:
            [
              %{
                title: "User Since",
                value: format_datetime_string(buyer["created_at"]),
                short: true
              }
            ] ++ seller_admin(seller)
        }
      ]
  end

  defp append_order_info(attachments, order) do
    attachments ++
      [
        %{
          color: "#20639B",
          author_name: order["code"],
          author_link: exchange_admin_link(order["id"]),
          fields:
            [
              %{
                title: "#{order["mode"]} / #{order["fulfillment_type"]}",
                value:
                  format_price(
                    order["items_total_cents"],
                    order["currency_code"]
                  ),
                short: false
              }
            ] ++ fulfillment_info(order)
        }
      ]
  end

  defp append_transaction_info(attachments, event) do
    attachments ++
      [
        %{
          color: "#6E1FFF",
          title: event["properties"]["failure_message"],
          title_link: stripe_search_link(event["properties"]["order"]["id"]),
          author_name: "#{event["properties"]["failure_code"]} / #{event["properties"]["decline_code"]}",
          author_link: stripe_search_link(event["properties"]["order"]["id"]),
          fields:
            [
              %{
                title: "Transaction Type",
                value: event["properties"]["transaction_type"],
                short: true
              }
            ] ++ stripe_fields(event["properties"]["external_id"], event["properties"]["external_type"])
        }
      ]
  end

  defp fulfillment_info(order = %{"fulfillment_type" => "ship"}) do
    [
      %{title: "Shipping Country", value: order["shipping_country"], short: true},
      %{title: "Shipping Name", value: cleanup_name(order["shipping_name"]), short: true},
      %{title: "Shipping State", value: order["shipping_region"], short: true}
    ]
  end

  defp fulfillment_info(_), do: []

  defp seller_admin(%{"admin" => %{"name" => name}}) do
    [
      %{
        title: "Partner Admin",
        value: name,
        short: true
      }
    ]
  end

  defp seller_admin(_), do: []

  defp stripe_fields(external_id, external_type) do
    with {:ok, pi} <- @payments.payment_info(external_id, external_type) do
      [
        %{
          title: "Risk Level",
          value: pi.charge_data.risk_level,
          short: true
        },
        %{
          title: "Card Country",
          value: pi.card_country,
          short: true
        },
        %{
          title: "Billing State",
          value: pi.billing_state,
          short: true
        },
        %{
          title: "CVC Check  #{format_check(pi.cvc_check)}",
          short: true
        },
        %{
          title: "ZIP Check  #{format_check(pi.zip_check)}",
          short: true
        },
        %{
          title: "Liability Shift #{format_boolean(pi.charge_data.liability_shift)}",
          short: true
        }
      ]
    else
      _ -> []
    end
  end
end
