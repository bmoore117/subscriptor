use aiken/bytearray
use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Output, ScriptContext, Spend, Transaction,
} as tx
use aiken/transaction/credential.{
  ScriptCredential, VerificationKey, VerificationKeyCredential,
}
use aiken/transaction/value

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
  billable_amount: Int,
  // merchant's ID to mint spending tokens with
  merchant_vk: VerificationKeyHash,
}

// Only the person who deployed the contract can mint or burn CIP 68 reference tokens, which detail a subscription. 
// The merchant a user has subscribed to can mint a single spending token per month which corresponds to an existing reference token 
// and allows the merchant to collect only the amount due from amounts held in user deposit governed contract UTXOs. 
// Only the owner or someone possessing a spending key can unlock funds from these deposits.

// TODO: Draft date logic: first, establish year-in-seconds
// then divide epoch seconds by year-in-seconds to get number of years
// number of years will also give number of leap days
// then subtract days by month, when the number of seconds left is less than a day's worth, you have arrived at the date
// recursion is the only way to loop so do it recursively
validator(owner_vk: VerificationKeyHash, platform_vk: VerificationKeyHash) {
  fn handle_subscription(rdmr: Action, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx

    expect tx.Mint(own_policy_id) = purpose

    let Transaction { reference_inputs, outputs, mint, validity_range, .. } =
      transaction

    expect [(minted_asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(own_policy_id)
        |> dict.to_list()

    let signed = list.has(transaction.extra_signatories, owner_vk)
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
        // anchor asset name must start with CIP68 prefix
        let cip_68_reference_prefixed =
          when bytearray.index_of(minted_asset_name, #"000643b0") is {
            Some((0, _)) -> True
            _other -> False
          }

        // anchor needs to go to a UTXO at this script's address, which must also have an inline datum. There should only be 1 output datum across all the outputs
        expect [Output { datum: InlineDatum(output_datum), .. }] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == ScriptCredential(
                own_policy_id,
              )
            },
          )

        expect new_subscription_details: SubscriptionDetails = output_datum

        // 1 anchor is minted by the owner, having the correct cip68 prefix, with a next billing date of 1 month from now, and a nonzero billing amount
        (amount == 1)? && signed? && cip_68_reference_prefixed? && (new_subscription_details.lock_until >= upper_range_value + 2592000000)? && (new_subscription_details.billable_amount > 0)?
      }
      MintSpendingToken -> {
        // expect the anchor token to be in the reference inputs as we mint the corresponding spending token
        expect [anchor_input] =
          list.filter(
            reference_inputs,
            fn(input) {
              value.quantity_of(
                input.output.value,
                own_policy_id,
                bytearray.concat(
                  #"000643b0",
                  bytearray.drop(minted_asset_name, 8),
                ),
              ) == 1
            },
          )
        // expect it to have a datum
        expect InlineDatum(anchor_datum_value) = anchor_input.output.datum
        expect details: SubscriptionDetails = anchor_datum_value

        // allow minting of 1 spending token by the merchant if we're past the last billing date, i.e. one month has elapsed since the last time of billing
        (amount == 1)? && (lower_range_value >= details.lock_until)? && list.has(
          transaction.extra_signatories,
          details.merchant_vk,
        )?
      }
      // TODO is it possible to check if the merchant is signing here? and then OR with owner check as well
      Burn -> (amount == -1)?
    }
  }

  fn redeem(_d: Data, _r: Data, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    let Transaction { inputs, outputs, reference_inputs, mint, .. } =
      transaction

    if list.has(transaction.extra_signatories, owner_vk) {
      // owner can always pull money out for any reason just like a debit card, it's their account
      True
    } else {
      // work our way to our own policy id, which should be the same as our own validator hash
      expect Spend(own_reference) = purpose
      expect Some(input) =
        list.find(inputs, fn(input) { input.output_reference == own_reference })
      let Output { address: in_address, .. } = input.output
      let credential = in_address.payment_credential
      expect ScriptCredential(own_policy_id) = credential

      // expect that we are only spending inputs from our own deposit contracts in the entire transaction, simplifies later checks
      expect
        list.all(
          inputs,
          fn(input) {
            input.output.address.payment_credential == ScriptCredential(
              own_policy_id,
            )
          },
        )

      // using our policy ID to lookup, bind the spending token asset name and amount to variables
      // they should be present in mint as things that are being burnt
      expect [(spending_token_asset_name, amount)] =
        mint
          |> value.from_minted_value
          |> value.tokens(own_policy_id)
          |> dict.to_list()

      // expect us to burn this token
      expect (amount == -1)?

      // find the subscription anchor in the inputs, should be 1 of 2 possibles to spend, the other being just deposits with ada in them.
      expect [anchor_input] =
        list.filter(
          inputs,
          fn(input) {
            value.quantity_of(
              input.output.value,
              own_policy_id,
              bytearray.concat(
                #"000643b0",
                bytearray.drop(spending_token_asset_name, 8),
              ),
            ) == 1
          },
        )

      // expect it to have a datum
      expect InlineDatum(anchor_datum_value) = anchor_input.output.datum
      expect details: SubscriptionDetails = anchor_datum_value

      // expect that this transaction was initiated by the merchant ID'd in the datum
      expect
        list.has(transaction.extra_signatories, details.merchant_vk) == True

      // expect anchor to be in the outputs and require it to also be going back to the user's deposits
      expect [own_output] =
        list.filter(
          outputs,
          fn(output: Output) {
            value.quantity_of(
              output.value,
              own_policy_id,
              bytearray.concat(
                #"000643b0",
                bytearray.drop(spending_token_asset_name, 8),
              ),
            ) == 1 && output.address.payment_credential == ScriptCredential(
              own_policy_id,
            )
          },
        )

      // expect it to have an updated datum having a billing date equal to last billing date + 1 month
      expect InlineDatum(output_datum_value) = own_output.datum
      expect output_details: SubscriptionDetails = output_datum_value
      expect
        (details.billable_amount == output_details.billable_amount)? && (details.merchant_vk == output_details.merchant_vk)? && (details.lock_until + 2592000000 == output_details.lock_until)?

      // expect outputs to either go to the merchant or back to the deposit
      expect
        list.all(
          outputs,
          fn(output) {
            output.address.payment_credential == ScriptCredential(own_policy_id) || output.address.payment_credential == VerificationKeyCredential(
              details.merchant_vk,
            )
          },
        )

      // get all outputs going to merchant
      let merchant_outputs =
        list.filter(
          outputs,
          fn(output) {
            output.address.payment_credential == VerificationKeyCredential(
              details.merchant_vk,
            )
          },
        )

      // expect total value going to merchant to be exactly billable amount 
      expect
        list.foldl(
          merchant_outputs,
          0,
          fn(output, total) {
            expect [(_ada_asset_name, ada_amount)] =
              output.value
                |> value.tokens(value.ada_policy_id)
                |> dict.to_list()
            ada_amount + total
          },
        ) == details.billable_amount
      // TODO: lookup platform fee schedule nft in reference inputs by policy ID, itself another CIP68 anchor, and ensure there is an output going to the platform with the correct amount
      True
    }
  }
}
