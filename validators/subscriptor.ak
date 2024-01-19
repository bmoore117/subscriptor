use aiken/bytearray
use aiken/dict
use aiken/list
use aiken/transaction.{OutputReference, ScriptContext, Transaction} as tx
use aiken/transaction/value
use aiken/transaction/credential.{VerificationKey}
use aiken/hash.{Blake2b_224, Hash}

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

type Action {
  MintAnchor,
  MintSpendingToken,
  Burn
}

type SubscriptionDetails {
  // POSIX time in second, e.g. 1672843961000
  lock_until: Int,
  
  // amount in ADA to allow deducting
  billable_amount: Int
}

// Only the person who deployed the contract can mint or burn 
// anchors or spending tokens - which together form a CIP-68 pair.
// Also, only the owner or someone possessing a spending key can unlock funds
validator(ownerVk: VerificationKeyHash) {
  fn handle_subscription(rdmr: Action, ctx: ScriptContext) -> Bool {
    let ScriptContext { tx, purpose } =
      ctx

    expect tx.Mint(own_policy_id) =
      purpose

    let Transaction { inputs, mint, validity_range, .. } =
      tx

    expect [(asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(own_policy_id)
        |> dict.to_list()

    let signed = list.has(tx.extra_signatories, ownerVk)
    let cip68ReferencePrefixed =
      when bytearray.index_of(asset_name, #"000643b0") is {
        Some((0, _)) -> True
        _other -> False
      }

    let cip68NamesAndPolicyMatch = option.or_else(option.map(list.at(tx.reference_inputs, 0), fn (input) {
      let inputAssetName = input.output.value.asset_name
      let inputPolicyId = input.output.value.own_policy_id
      bytearray.compare(inputPolicyId, own_policy_id) == Equal 
        && bytearray.compare(bytearray.concat(#"000de140", bytearray.drop(inputAssetName, 8)), asset_name) == Equal
    }), False)

    when rdmr is {
      MintAnchor -> {
        expect [Output { datum: InlineDatum(output_datum), value, .. }] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == ScriptCredential(own_policy_id)
            },
          )

        expect new_subscription_details: SubscriptionDetails = output_datum

        let Interval {
          upper_bound: IntervalBound {
            bound_type: upper_range,
            is_inclusive: upper_is_inclusive,
          },
          lower_bound: IntervalBound {
            bound_type: lower_range,
            is_inclusive: lower_is_inclusive,
          },
        } = validity_range

        // requirement: Time range span is 3 minutes or less and inclusive
        expect and {
            !upper_is_inclusive?,
            lower_is_inclusive?,
            (upper_range - lower_range <= 180000)?,
          }

        // TODO recheck bounds
        (amount == 1)? && signed? && cip68ReferencePrefixed? && (new_subscription_details.lock_until >= upper_range + 2592000000)? 
          && new_subscription_details.billable_amount > 0
      }
      MintSpendingToken -> {
        (amount == 1)? && signed? && cip68NamesAndPolicyMatch?
      }
      Burn ->
        (amount == -1)? && signed? && contained?
    }
  }

  fn redeem(_d: Data, _r: Data, ctx: ScriptContext) -> Bool {
    let ScriptContext { tx, .. } =
      ctx

    let Transaction { mint, .. } =
      tx

    list.has(tx.extra_signatories, ownerVk)
  }
}


