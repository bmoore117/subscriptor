use aiken/string
use aiken/builtin
use aiken/bytearray
use aiken/dict
use aiken/hash.{Blake2b_224, Hash}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, NoDatum, Output, ScriptContext, Spend, Transaction,
} as tx
use aiken/transaction/credential.{
  Script, ScriptCredential, VerificationKey, VerificationKeyCredential,
}
use aiken/transaction/value

type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

type ScriptCredentialHash =
  Hash<Blake2b_224, Script>

type MintAction {
  MintAnchor
  Burn
}

type WithdrawalAction {
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
validator(
  owner_vk: VerificationKeyHash,
  platform_policy_id: ScriptCredentialHash,
) {
  fn handle_subscription(rdmr: MintAction, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx

    expect tx.Mint(own_policy_id) = purpose

    let Transaction { outputs, mint, validity_range, .. } = transaction

    expect [(minted_asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(own_policy_id)
        |> dict.to_list()

    // requirement: the user initiated this transaction
    expect list.has(transaction.extra_signatories, owner_vk)
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

        // requirement: anchor needs to go to a UTXO at this script's address, which must also have an inline datum. There should only be 1 output datum across all the outputs
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

        // requirements: 1 anchor is minted by the owner, having the correct cip68 prefix, with a next billing date of 5 minutes from now, a nonzero billing amount, and a non-empty merchant_vk
        (amount == 1)? && cip_68_reference_prefixed? && (new_subscription_details.lock_until >= upper_range_value + 300000)? && (new_subscription_details.billable_amount > 0)? && !bytearray.is_empty(
          new_subscription_details.merchant_vk,
        )?
      }
      // TODO is it possible to check if the merchant is signing here? and then OR with owner check as well
      Burn -> (amount == -1)?
    }
  }

  fn redeem(_d: Data, rdmr: WithdrawalAction, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } = ctx
    let Transaction { inputs, outputs, reference_inputs, .. } = transaction
    trace "Got context"

    if
    (rdmr == Withdraw)? && list.has(transaction.extra_signatories, owner_vk)? && list.all(
      inputs,
      fn(input) { input.output.datum == NoDatum },
    )?{
      trace "Withdrawing"
      // owner can always pull money out for any reason just like a debit card, it's their account
      // however we need to make sure they don't accidentally delete any subscription datum by spending it
      True
    } else if rdmr == CollectPayment {
      trace "Collecting"
      // work our way to our own policy id, which should be the same as our own validator hash
      expect Spend(own_reference) = purpose
      expect Some(input) =
        list.find(inputs, fn(input) { input.output_reference == own_reference })
      let Output { address: in_address, .. } = input.output
      let credential = in_address.payment_credential
      expect ScriptCredential(own_policy_id) = credential
      trace "Policy obtained"

      // in the inputs there should be total only 1 datum attached to a UTXO with our script policy ID - the one we're 
      // going to be collecting from. shouldn't have to worry about datums with other policy IDs - this script can't witness those unlocks
      expect [anchor_input] =
        list.filter(
          inputs,
          fn(input) {
            when input.output.datum is {
              InlineDatum(datum_value) -> is_subscription_datum(datum_value) 
              // We'll let you spend inputs with NoDatum or a datum hash, 
              // even if that hash actually would correspond to our datum type, 
              // because we only create InlineDatums so you have been doing non-standard things
              _other -> False
            }
          },
        )
      trace "Got anchor"
      
      // get token name now we have the input it's at, so we can use to simplify below
      expect [(subscription_details_asset_name, _amount)] =
        dict.to_list(value.tokens(anchor_input.output.value, own_policy_id))
      trace "Got asset name"

      // expect it to have a datum
      expect InlineDatum(anchor_datum_value) = anchor_input.output.datum
      expect details: SubscriptionDetails = anchor_datum_value
      trace "Got subscription datum"

      // expect anchor to be in the outputs and require it to also be going back to the user's deposits
      expect [own_output] =
        list.filter(
          outputs,
          fn(output: Output) {
            value.quantity_of(
              output.value,
              own_policy_id,
              subscription_details_asset_name,
            ) == 1 && output.address.payment_credential == ScriptCredential(
              own_policy_id,
            )
          },
        )
      trace "verified anchor in outputs"

      // expect it to have an updated datum having a billing date equal to last billing date + 5 minutes (for now, for testing)
      expect InlineDatum(output_datum_value) = own_output.datum
      expect output_details: SubscriptionDetails = output_datum_value
      expect
        (details.billable_amount == output_details.billable_amount)? && (details.merchant_vk == output_details.merchant_vk)? && (details.lock_until + 300000 == output_details.lock_until)?
      trace "verified new subscription output datum"
      // expect total value going to merchant to be == billable amount 
      let merchant_amount = list.foldl(
          outputs,
          0,
          fn(output, total) {
            when output.address.payment_credential is {
              VerificationKeyCredential(merchant_addr) -> {
                trace string.concat(@"addr: ", bytearray.to_hex(merchant_addr))
                if (merchant_addr == details.merchant_vk) {
                  trace "found merchant output"
                  expect [(_ada_asset_name, ada_amount)] =
                    output.value
                    |> value.tokens(value.ada_policy_id)
                    |> dict.to_list()
                  trace string.concat(@"amount: ", string.from_int(ada_amount))
                  ada_amount + total
                } else {
                  total + 0
                }
              }
              _other -> total + 0
            }
          },
        )
      trace string.concat(@"Total merchant amount: ", string.from_int(merchant_amount))
      expect merchant_amount == details.billable_amount
      trace "verified merchant receipt"
      // expect the platform fee schedule to be in the reference inputs
      expect [platform_input] =
        list.filter(
          reference_inputs,
          fn(input) {
            value.quantity_of(
              input.output.value,
              platform_policy_id,
              // "PlatformFeeSchedule", prefixed with CIP-68 reference token identifier
              #"000643b0506c6174666f726d4665655363686564756c65",
            ) == 1
          },
        )
      expect InlineDatum(platform_datum_value) = platform_input.output.datum
      expect platform_details: PlatformFeeSchedule = platform_datum_value
      trace "found platform datum"

      // platform collects a percentage of the total going to the merchant
      expect
        list.foldl(
          outputs,
          0,
          fn(output, total) {
            if
            output.address.payment_credential == VerificationKeyCredential(
              platform_details.platform_vk,
            ){
            
              expect [(_ada_asset_name, ada_amount)] =
                output.value
                  |> value.tokens(value.ada_policy_id)
                  |> dict.to_list()
              ada_amount + total
            } else {
              total + 0
            }
          },
        ) == platform_details.fee_percentage_basis_points * details.billable_amount / 1000
      trace "verified platform receipt"
      // if every condition met thus far, return true
      True
    } else {
      // We didn't pass Withdraw or CollectPayment in the redeemer, or didn't have deposit owner signature for a Withdraw
      False
    }
  }
}

fn is_subscription_datum(any: Data) -> Bool {
  let is_constr =
    builtin.choose_data(_, True, False, False, False, False)

  let is_int =
    builtin.choose_data(_, False, False, False, True, False)

  let is_bytes =
    builtin.choose_data(_, False, False, False, False, True)

  if is_constr(any) {
    let (constructor, fields) = builtin.un_constr_data(any)
    and {
      constructor == 0,
      when list.at(fields, 0) is {
        Some(field) -> is_int(field)
        None -> False
      },
      when list.at(fields, 1) is {
        Some(field) -> is_int(field)
        None -> False
      },
      when list.at(fields, 2) is {
        Some(field) -> is_bytes(field)
        None -> False
      }
    }
  } else {
    False
  }
}
