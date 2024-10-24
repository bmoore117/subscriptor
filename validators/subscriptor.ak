use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, ScriptHash}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/math
use aiken/primitive/bytearray
use aiken/primitive/string
use cardano/address.{VerificationKey, Script}
use cardano/assets.{PolicyId}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference, Transaction}

pub type MintAction {
  MintAnchor
  Burn
}

pub type WithdrawalAction {
  Withdraw
  CollectPayment
}

type SubscriptionDetails {
  // POSIX time in second, e.g. 1672843961000
  lock_until: Int,
  // amount in ADA to allow deducting
  billable_amount: Int,
  // merchant's ID to mint spending tokens with
  merchant_vk: VerificationKeyHash,
}

type PlatformFeeSchedule {
  fee_percentage_basis_points: Int,
  platform_vk: VerificationKeyHash,
  min_utxo_cost_lovelace: Int,
}
 
validator subscriptor(owner_vk: VerificationKeyHash, platform_policy_id: ScriptHash) {
  spend(_d: Option<Data>, rdmr: WithdrawalAction, own_reference: OutputReference, transaction: Transaction) -> Bool {
    trace @"Build #10"
    let Transaction { inputs, outputs, reference_inputs, .. } = transaction
    trace @"Got context"

    if (rdmr == Withdraw)? && list.has(transaction.extra_signatories, owner_vk)? && list.all(inputs, fn(input) { input.output.datum == NoDatum })? {
      trace @"Withdrawing"
      // owner can always pull money out for any reason just like a debit card, it's their account
      // however we need to make sure they don't accidentally delete any subscription datum by spending it
      True
    } else if rdmr == CollectPayment {
      trace @"Collecting"
      // work our way to our own policy id, which should be the same as our own validator hash
      expect Some(input) = list.find(inputs, fn(input) { input.output_reference == own_reference })
      expect Script(own_policy_id) = input.output.address.payment_credential
      trace @"Policy obtained"

      // in the inputs there should be total only 1 datum attached to a UTXO with our script policy ID - the one we're 
      // going to be collecting from. shouldn't have to worry about datums with other policy IDs - this script can't witness those unlocks
      expect [anchor_input] = list.filter(inputs,
        fn(input) {
          when input.output.datum is {
            InlineDatum(datum_value) -> if datum_value is SubscriptionDetails {True} else {False}
            _other -> False
          }
        },
      )
      trace @"Got anchor"
      // get token name now we have the input it's at, so we can use to simplify below
      expect [Pair(subscription_details_asset_name, _amount)] = dict.to_pairs(assets.tokens(anchor_input.output.value, own_policy_id))
      trace @"Got asset name"

      // expect it to have a datum
      expect InlineDatum(anchor_datum_value) = anchor_input.output.datum
      expect details: SubscriptionDetails = anchor_datum_value
      trace @"Got subscription datum"

      // expect the platform fee schedule to be in the reference inputs
      expect [platform_input] = list.filter(reference_inputs,
        fn(input) {
          // "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
          assets.quantity_of(input.output.value, platform_policy_id, #"000643b0506c6174666f726d4665655363686564756c65") == 1
        }
      )
      expect InlineDatum(platform_datum_value) = platform_input.output.datum
      expect platform_details: PlatformFeeSchedule = platform_datum_value
      trace @"found platform datum"

      // expect first output to be to platform, with proper fee
      expect Some(platform_output) = list.at(outputs, 0)
      let platform_collectable = math.max(platform_details.fee_percentage_basis_points * details.billable_amount / 1000, platform_details.min_utxo_cost_lovelace)
      expect platform_collectable == assets.lovelace_of(platform_output.value)

      // we may be spending multiple inputs to clear the subscription amount, so total up inputs
      let input_total = list.foldl(inputs, 0, fn(input, result) {
        when input.output.address.payment_credential is {
          Script(policy_id) -> {
            if policy_id == own_policy_id {
              result + assets.lovelace_of(input.output.value)
            } else {
              result + 0
            }
          }
          _other -> result + 0
        }
      })

      // establish how much should be coming back to the contract once the platform fee and the merchant collectible are subtracted
      let merchant_collectible = math.max(details.billable_amount, platform_details.min_utxo_cost_lovelace)
      let contract_return = input_total - platform_collectable - merchant_collectible
      
      // expect the second output to be back to the contract with this amount
      expect Some(contract_output) = list.at(outputs, 1)
      expect contract_output.address.payment_credential == Script(own_policy_id)
      expect contract_return == assets.lovelace_of(contract_output.value)
      expect assets.quantity_of(contract_output.value, own_policy_id, subscription_details_asset_name) == 1
      trace @"Verified output going to user has anchor & proper change return"
      
      // expect it to also have an updated datum having a billing date equal to last billing date + 5 minutes (for now, for testing)
      expect InlineDatum(output_datum_value) = contract_output.datum
      expect output_details: SubscriptionDetails = output_datum_value
      trace string.from_int(output_details.lock_until)
      trace string.from_int(details.lock_until)
      expect (details.billable_amount == output_details.billable_amount)? 
        && (details.merchant_vk == output_details.merchant_vk)? 
        && (details.lock_until + 300000 == output_details.lock_until)?

      // expect the third output to be back to the merchant with at least merchant amount - prevents others from claiming
      // also is flexible allowing merchant to have a payment output and a separate change output (as in CLI) or a single combined output
      // this is safe as we previously verified the amount coming back to the contract and going to the platform
      expect Some(merchant_output) = list.at(outputs, 2)
      expect VerificationKey(subject_addr) = merchant_output.address.payment_credential
      expect subject_addr == details.merchant_vk
      assets.lovelace_of(merchant_output.value) >= merchant_collectible
    } else {
      // We didn't pass Withdraw or CollectPayment in the redeemer, or didn't have deposit owner signature for a Withdraw
      False
    }
  }
 
  mint(rdmr: MintAction, own_policy_id: PolicyId, tx: Transaction) -> Bool {
    trace @"Here 1"
    let Transaction { outputs, mint, validity_range, .. } = tx

    expect [Pair(minted_asset_name, amount)] =
      mint
        |> assets.tokens(own_policy_id)
        |> dict.to_pairs()

    // requirement: the user initiated this transaction
    // NOTE: commenting this to generate a different build
    // expect list.has(transaction.extra_signatories, owner_vk)
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
        trace @"Here 2"
        // requirement: anchor asset name must start with CIP68 prefix
        let cip_68_reference_prefixed =
          when bytearray.index_of(minted_asset_name, #"000643b0") is {
            Some((0, _)) -> True
            _other -> False
          }

        trace @"Here 3"
        // requirement: anchor needs to go to a UTXO at this script's address, in the form of an inline datum. There should only be 1 output datum across all the outputs
        expect [Output { datum: InlineDatum(output_datum), .. }] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == Script(own_policy_id)
            }
          )
        
        expect new_subscription_details: SubscriptionDetails = output_datum

        trace @"Here 4"
        // requirements: 1 anchor is minted by the owner, having the correct cip68 prefix, with a next billing date of 5 minutes from now, a nonzero billing amount, and a non-empty merchant_vk
        (amount == 1)? && cip_68_reference_prefixed? && (new_subscription_details.lock_until >= upper_range_value + 300000)? && (new_subscription_details.billable_amount > 0)? && !bytearray.is_empty(
          new_subscription_details.merchant_vk,
        )?
      }
      // TODO is it possible to check if the merchant is signing here? and then OR with owner check as well
      Burn -> (amount == -1)?
    }
  }
}