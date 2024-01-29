use aiken/bytearray
use aiken/dict
use aiken/list
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/transaction.{InlineDatum, Input, Output, ScriptContext, Transaction} as tx
use aiken/transaction/value
use aiken/transaction/credential.{ScriptCredential, VerificationKey}
use aiken/hash.{Blake2b_224, Hash}

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

type Action {
  MintAnchor
  MintSpendingToken
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

// NB: since we need to update the datum of the anchor after every spend token mint, we need to move and "spend" the anchor on each mint
// so if we can move it from the deposit contract to the deposit contract, a 0-move move, that's fine, otherwise we'll need a bag of holding 
// together with the deposit contract to bounce the anchor in and out of and generate new datums with

// TODO: ensure new output datum exists in transaction for anchor on spending token mint
validator(ownerVk: VerificationKeyHash) {
  fn handle_subscription(rdmr: Action, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } =
      ctx

    expect tx.Mint(own_policy_id) =
      purpose

    let Transaction { inputs, outputs, mint, validity_range, .. } =
      transaction

    expect [(minted_asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(own_policy_id)
        |> dict.to_list()

    let signed = list.has(transaction.extra_signatories, ownerVk)
    
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

    expect Finite(upper_range_value) = upper_range
    expect Finite(lower_range_value) = lower_range

    // requirement: this transaction was minted with a three minute or less validity range
    // so we have some bound on when "now" is
    expect and {
      !upper_is_inclusive?,
      lower_is_inclusive?,
      (upper_range_value - lower_range_value <= 180000)?,
    }

    when rdmr is {
      MintAnchor -> {
        let cip68ReferencePrefixed =
          when bytearray.index_of(minted_asset_name, #"000643b0") is {
            Some((0, _)) -> True
            _other -> False
        }

        expect [Output { datum: InlineDatum(output_datum), .. }] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == ScriptCredential(own_policy_id)
            }
          )

        expect new_subscription_details: SubscriptionDetails = output_datum

        // TODO recheck bounds
        (amount == 1)? 
          && signed? 
          && cip68ReferencePrefixed? 
          && (new_subscription_details.lock_until >= upper_range_value + 2592000000)? 
          && (new_subscription_details.billable_amount > 0)?
      }
      MintSpendingToken -> {
        (amount == 1)? 
          && signed? 
          && is_cip_68_spending_token_for_corresponding_reference_token(inputs, own_policy_id, minted_asset_name)? 
          && is_past_last_billing_period(inputs, own_policy_id, minted_asset_name, lower_range_value)
      }
      Burn ->
        (amount == -1)? && signed?
    }
  }

  fn redeem(_d: Data, _r: Data, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, .. } =
      ctx

    let Transaction { mint, .. } =
      transaction

    list.has(transaction.extra_signatories, ownerVk)
  }
}

fn is_cip_68_spending_token_for_corresponding_reference_token(inputs: List<Input>, own_policy_id: ByteArray, minted_asset_name: ByteArray) -> Bool {
  list.any(inputs, fn (input) {
    value.quantity_of(input.output.value, own_policy_id, bytearray.concat(#"000643b0", bytearray.drop(minted_asset_name, 8))) == 1
  })
}

fn is_past_last_billing_period(inputs: List<Input>, own_policy_id: ByteArray, minted_asset_name: ByteArray, lower_range_value: Int) -> Bool {
  list.any(inputs, fn (input) {
    let anchor_found = value.quantity_of(input.output.value, own_policy_id, bytearray.concat(#"000643b0", bytearray.drop(minted_asset_name, 8))) > 0
    
    if (anchor_found) {
      expect InlineDatum(output_datum_value) = input.output.datum
      expect details: SubscriptionDetails = output_datum_value
      lower_range_value >= details.lock_until
    } else {
      False
    }
  })
}