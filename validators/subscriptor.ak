use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/math
use aiken/primitive/bytearray
use aiken/primitive/string
use cardano/address.{Script, VerificationKey}
use cardano/assets.{PolicyId}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}

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

validator subscriptor(
  owner_vk: VerificationKeyHash,
  platform_policy_id: ScriptHash,
) {
  spend(
    _d: Option<Data>,
    rdmr: WithdrawalAction,
    own_reference: OutputReference,
    transaction: Transaction,
  ) {
    // do not update, incremented automatically
    trace @"Build #72"
    let Transaction { inputs, outputs, reference_inputs, .. } = transaction
    trace @"Got context"

    if (rdmr == Withdraw)? && list.has(transaction.extra_signatories, owner_vk)? && list.all(
      inputs,
      fn(input) { input.output.datum == NoDatum },
    )? {
      trace @"Withdrawing"
      // owner can always pull money out for any reason just like a debit card, it's their account
      // however we need to make sure they don't accidentally delete any subscription datum by spending it
      True
    } else if rdmr == CollectPayment {
      trace @"Collecting"
      // work our way to our own policy id, which should be the same as our own validator hash
      expect Some(input) =
        list.find(inputs, fn(input) { input.output_reference == own_reference })
      expect Script(own_policy_id) = input.output.address.payment_credential
      trace @"Policy obtained"

      // in the inputs there should be total only 1 datum attached to a UTXO with our script policy ID - the one we're 
      // going to be collecting from. shouldn't have to worry about datums with other policy IDs - this script can't witness those unlocks
      expect [anchor_input] =
        list.filter(
          inputs,
          fn(input) {
            when input.output.datum is {
              InlineDatum(datum_value) ->
                if datum_value is SubscriptionDetails {
                  True
                } else {
                  False
                }
              _other -> False
            }
          },
        )
      trace @"Got anchor"
      // get token name now we have the input it's at, so we can use to simplify below
      expect [Pair(subscription_details_asset_name, _amount)] =
        dict.to_pairs(assets.tokens(anchor_input.output.value, own_policy_id))
      trace @"Got asset name"

      // expect it to have a datum
      expect InlineDatum(anchor_datum_value) = anchor_input.output.datum
      expect details: SubscriptionDetails = anchor_datum_value
      trace @"Got subscription datum"

      // expect the platform fee schedule to be in the reference inputs
      expect [platform_input] =
        list.filter(
          reference_inputs,
          fn(input) {
            // "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
            assets.quantity_of(
              input.output.value,
              platform_policy_id,
              #"000643b0506c6174666f726d4665655363686564756c65",
            ) == 1
          },
        )
      expect InlineDatum(platform_datum_value) = platform_input.output.datum
      expect platform_details: PlatformFeeSchedule = platform_datum_value
      trace @"Found platform datum"

      // expect first output to be to platform, with proper fee
      expect Some(platform_output) = list.at(outputs, 0)
      let platform_collectable =
        math.max(
          platform_details.fee_percentage_basis_points * details.billable_amount / 1000,
          platform_details.min_utxo_cost_lovelace,
        )
      expect VerificationKey(subject_addr) =
        platform_output.address.payment_credential
      expect subject_addr == platform_details.platform_vk
      expect platform_collectable == assets.lovelace_of(platform_output.value)

      // expect second output to be to merchant, with billable amount
      expect Some(merchant_output) = list.at(outputs, 1)
      let merchant_collectible =
        math.max(
          details.billable_amount,
          platform_details.min_utxo_cost_lovelace,
        )
      expect VerificationKey(subject_addr) =
        merchant_output.address.payment_credential
      expect subject_addr == details.merchant_vk
      expect assets.lovelace_of(merchant_output.value) == merchant_collectible

      // expect third output to be the contract change plus updated datum
      expect Some(contract_change) = list.at(outputs, 2)
      trace contract_change.address.payment_credential
      trace own_policy_id
      trace Script(own_policy_id)
      expect contract_change.address.payment_credential == Script(own_policy_id)
      // calculate total ADA from all contract input utxos
      let contract_input_total =
        list.foldl(
          inputs,
          0,
          fn(input, total) {
            if input.output.address.payment_credential == Script(own_policy_id) {
              assets.lovelace_of(input.output.value) + total
            } else {
              0 + total
            }
          },
        )
      // wanted: a tx where the merchant must cover the fees personally, and can only have a positive net 
      // (well, unless fees were greater than the merchant take, but we know from experience that the minimum take, i.e. the minimum utxo, exceeds fees as currently written)
      // and where the contract does not receive any stealth ada from the merchant to re-create the anchor + datum contract utxo.
      // verify this by asserting that the contract output must be exactly equal to and no greater than the contract total input - platform collectable - merchant collectable
      // as being greater than this quantity would indicate that the merchant had been the victim of coin selection algorithms that signed him up for a loss, which he was probably not expecting
      // why must the merchant cover the fees? well, because the user in general is not "doing" this transaction, they are being collected from by the merchant
      // and because the user is our direct customer in a way the merchant isn't quite
      expect
        assets.lovelace_of(contract_change.value) == contract_input_total - platform_collectable - merchant_collectible
      expect
        assets.quantity_of(
          contract_change.value,
          own_policy_id,
          subscription_details_asset_name,
        ) == 1
      trace @"Verified anchor output exists"
      // expect it to also have an updated datum having a billing date equal to last billing date + 5 minutes (for now, for testing)
      expect InlineDatum(output_datum_value) = contract_change.datum
      expect output_details: SubscriptionDetails = output_datum_value
      trace string.from_int(output_details.lock_until)
      trace string.from_int(details.lock_until)
      expect details.lock_until + 300000 == output_details.lock_until
      (details.billable_amount == output_details.billable_amount)? && (details.merchant_vk == output_details.merchant_vk)?
    } else {
      // We didn't pass Withdraw or CollectPayment in the redeemer, or didn't have deposit owner signature for a Withdraw
      False
    }
  }

  mint(rdmr: MintAction, own_policy_id: PolicyId, tx: Transaction) {
    // do not update, incremented automatically
    trace @"Build #72"
    let Transaction { outputs, mint, validity_range, .. } = tx

    expect [Pair(minted_asset_name, amount)] =
      mint
        |> assets.tokens(own_policy_id)
        |> dict.to_pairs()

    // requirement: the user initiated this transaction
    expect list.has(tx.extra_signatories, owner_vk)
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
        // requirement: anchor asset name must start with CIP68 prefix
        let cip_68_reference_prefixed =
          when bytearray.index_of(minted_asset_name, #"000643b0") is {
            Some((0, _)) -> True
            _other -> False
          }

        // requirement: anchor needs to go to a UTXO at this script's address, in the form of an inline datum. There should only be 1 output datum across all the outputs
        expect [Output { datum: InlineDatum(output_datum), .. }] =
          list.filter(
            outputs,
            fn(output) {
              output.address.payment_credential == Script(own_policy_id)
            },
          )
        expect new_subscription_details: SubscriptionDetails = output_datum
        trace new_subscription_details.lock_until
        trace upper_range_value

        // requirements: 1 anchor is minted by the owner, having the correct cip68 prefix, with a next billing date of 5 minutes from now, a nonzero billing amount, and a non-empty merchant_vk
        (amount == 1)? && cip_68_reference_prefixed? && (new_subscription_details.lock_until >= upper_range_value + 300000)? && (new_subscription_details.billable_amount > 0)? && !bytearray.is_empty(
          new_subscription_details.merchant_vk,
        )?
      }
      // TODO is it possible to check if the merchant is signing here? and then OR with owner check as well
      Burn -> (amount == -1)?
    }
  }

  else(_) {
    fail
  }
}
