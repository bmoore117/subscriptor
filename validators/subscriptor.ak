use aiken/cbor
use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{VerificationKeyHash, ScriptHash}
use aiken/interval.{Finite, Interval, IntervalBound}
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

      // output is only allowed to merchant, platform, and back to contract
      expect list.all(outputs, fn(output) {  
        when output.address.payment_credential is {
          VerificationKey(subject_addr) -> subject_addr == details.merchant_vk || subject_addr == platform_details.platform_vk
          Script(policy_id) -> policy_id == own_policy_id 
        }
      })

      // gather amount going to merchant, platform, and total amount of ada being moved in this transaction
      let output_values = list.foldl(outputs, (0, 0, 0),
        fn(output, result_values) {
          expect [Pair(_ada_asset_name, ada_amount)] =
            output.value
              |> assets.tokens(assets.ada_policy_id)
              |> dict.to_pairs()
          when output.address.payment_credential is {
            VerificationKey(subject_addr) ->
              if subject_addr == details.merchant_vk {
                (ada_amount + result_values.1st, result_values.2nd, ada_amount + result_values.3rd)
              } else {
                (result_values.1st, ada_amount + result_values.2nd, ada_amount + result_values.3rd)
              }
            _contract -> (result_values.1st, result_values.2nd, ada_amount + result_values.3rd)
          }
        }
      )
      
      trace string.concat(@"Total merchant amount: ", string.from_int(output_values.1st))
      trace string.concat(@"Billable amount: ", string.from_int(details.billable_amount))
      expect if (details.billable_amount < platform_details.min_utxo_cost_lovelace) {
        output_values.1st == platform_details.min_utxo_cost_lovelace
      } else {
        output_values.1st == details.billable_amount
      }
      trace @"verified merchant receipt"
      
      trace string.concat(@"Total platform amount: ",string.from_int(output_values.2nd))
      let platform_collectable = platform_details.fee_percentage_basis_points * details.billable_amount / 1000
      expect if (platform_collectable < platform_details.min_utxo_cost_lovelace) {
        output_values.2nd == platform_details.min_utxo_cost_lovelace
      } else {
        output_values.2nd == platform_collectable
      }
      trace @"verified platform receipt"
      
      // expect anchor to be in the outputs and require it to also be going back to the user's deposits
      expect [own_output] = list.filter(outputs,
        fn(output: Output) {
          assets.quantity_of(
            output.value,
            own_policy_id,
            subscription_details_asset_name,
          ) == 1 && output.address.payment_credential == Script(
            own_policy_id,
          )
        },
      )
      trace @"verified anchor in outputs"

      // expect it to have an updated datum having a billing date equal to last billing date + 5 minutes (for now, for testing)
      expect InlineDatum(output_datum_value) = own_output.datum
      expect output_details: SubscriptionDetails = output_datum_value
      trace string.from_int(output_details.lock_until)
      trace string.from_int(details.lock_until)
      expect(details.billable_amount == output_details.billable_amount)? 
        && (details.merchant_vk == output_details.merchant_vk)? 
        && (details.lock_until + 300000 == output_details.lock_until)?

      trace(cbor.diagnostic(own_output.value))
      // expect all remaining ADA not going to merchant or platform to be in the same single output containing the updated subscription details
      let contract_amt = assets.quantity_of(own_output.value, "", "")
      trace string.concat(@"Amount returning to contract: ", string.from_int(contract_amt))
      contract_amt == contract_amt
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