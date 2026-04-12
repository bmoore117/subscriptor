use aiken/collection/dict
use aiken/collection/list
use aiken/crypto.{ScriptHash, VerificationKeyHash}
use aiken/interval.{Finite, Interval, IntervalBound}
use aiken/math
use aiken/primitive/bytearray
use aiken/primitive/string
use cardano/address.{Address, Script, VerificationKey}
use cardano/assets.{AssetName, PolicyId, add, from_asset, from_lovelace}
use cardano/transaction.{
  InlineDatum, Input, NoDatum, Output, OutputReference, Transaction,
}
use date.{BillingSchedule, BiWeekly, Daily, EveryNMilliseconds, Monthly, Weekly}

pub type MintAction {
  MintAnchor
  Burn
}

pub type WithdrawalAction {
  Withdraw
  CollectPayment(Int)
}

type SubscriptionDetails {
  // POSIX time in milliseconds
  lock_until: Int,
  // amount to allow deducting per billing cycle
  billable_amount: Int,
  // payment currency, be that ADA, stables, etc
  billable_unit: PolicyId,
  billable_unit_name: AssetName,
  // merchant's verification key hash
  merchant_vk: VerificationKeyHash,
  billing_schedule: BillingSchedule,
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
    trace @"Build #89"
    let Transaction { inputs, reference_inputs, outputs, validity_range, .. } =
      transaction
    trace @"Got context"

    when rdmr is {
      Withdraw -> {
        trace @"Withdrawing"
        // owner can always pull money out for any reason just like a debit card, it's their account
        // however we need to make sure they don't accidentally delete any subscription datum by spending it
        list.has(transaction.extra_signatories, owner_vk)? && list.all(
          inputs,
          fn(input) { input.output.datum == NoDatum },
        )?
      }
      CollectPayment(output_offset) -> {
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

        let Interval {
          upper_bound: IntervalBound {
            bound_type: _upper_range,
            is_inclusive: _upper_is_inclusive,
          },
          lower_bound: IntervalBound {
            bound_type: lower_range,
            is_inclusive: _lower_is_inclusive,
          },
        } = validity_range

        expect Finite(lower_range_value) = lower_range
        // expect now to be after lock_until
        expect lower_range_value > details.lock_until

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

        let collection_currency_ada =
          details.billable_unit == assets.ada_policy_id

        // three consecutive outputs starting at output_offset: platform, merchant, contract change
        expect Some(platform_output) = list.at(outputs, output_offset)
        expect VerificationKey(subject_addr) =
          platform_output.address.payment_credential
        expect subject_addr == platform_details.platform_vk
        let platform_collectable =
          if collection_currency_ada {
            math.max(
              platform_details.fee_percentage_basis_points * details.billable_amount / 1000,
              platform_details.min_utxo_cost_lovelace,
            )
          } else {
            platform_details.fee_percentage_basis_points * details.billable_amount / 1000
          }
        expect
          platform_collectable == assets.quantity_of(
            platform_output.value,
            details.billable_unit,
            details.billable_unit_name,
          )

        expect Some(merchant_output) = list.at(outputs, output_offset + 1)
        expect VerificationKey(subject_addr) =
          merchant_output.address.payment_credential
        expect subject_addr == details.merchant_vk
        expect
          assets.quantity_of(
            merchant_output.value,
            details.billable_unit,
            details.billable_unit_name,
          ) == details.billable_amount

        expect Some(contract_change) = list.at(outputs, output_offset + 2)
        expect contract_change.address.payment_credential == Script(own_policy_id)
        // calculate total input from all contract input utxos
        let contract_input_total =
          list.foldl(
            inputs,
            0,
            fn(input, total) {
              if input.output.address.payment_credential == Script(own_policy_id) {
                assets.quantity_of(
                  input.output.value,
                  details.billable_unit,
                  details.billable_unit_name,
                ) + total
              } else {
                0 + total
              }
            },
          )
        expect
          assets.quantity_of(
            contract_change.value,
            details.billable_unit,
            details.billable_unit_name,
          ) == contract_input_total - platform_collectable - details.billable_amount
        let no_ada_received_from_tx_initiator =
          if details.billable_unit == assets.ada_policy_id {
            True
          } else {
            let input_ada =
              list.foldl(
                inputs,
                0,
                fn(input, total) {
                  if input.output.address.payment_credential == Script(
                    own_policy_id,
                  ) {
                    assets.lovelace_of(input.output.value) + total
                  } else {
                    0 + total
                  }
                },
              )
            let platform_ada = assets.lovelace_of(platform_output.value)
            let merchant_ada = assets.lovelace_of(merchant_output.value)
            assets.lovelace_of(contract_change.value) == input_ada - platform_ada - merchant_ada
          }
        expect no_ada_received_from_tx_initiator

        expect
          assets.quantity_of(
            contract_change.value,
            own_policy_id,
            subscription_details_asset_name,
          ) == 1
        trace @"Verified anchor output exists"
        expect InlineDatum(output_datum_value) = contract_change.datum
        expect output_details: SubscriptionDetails = output_datum_value
        let expected_lock =
          date.next_billing_date(details.lock_until, details.billing_schedule)
        expect expected_lock == output_details.lock_until
        (details.billable_amount == output_details.billable_amount)? && (details.merchant_vk == output_details.merchant_vk)? && (details.billing_schedule == output_details.billing_schedule)?
      }
    }
  }

  mint(rdmr: MintAction, own_policy_id: PolicyId, tx: Transaction) {
    // do not update, incremented automatically
    trace @"Build #89"
    let Transaction { outputs, reference_inputs, mint, validity_range, .. } = tx

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

        // requirements: 1 anchor is minted by the owner, having the correct cip68 prefix, 
        // with a given billing schedule, a nonzero billing amount if CNT, 
        // or a billing amount over the minimum utxo if ADA, and a non-empty merchant_vk
        expect amount == 1
        expect cip_68_reference_prefixed
        expect !bytearray.is_empty(new_subscription_details.merchant_vk)
        expect when new_subscription_details.billing_schedule is {
          EveryNMilliseconds(n) -> n > 0
          _ -> True
        }
        let expected_first_billing =
          date.next_billing_date(
            upper_range_value,
            new_subscription_details.billing_schedule,
          )
        expect new_subscription_details.lock_until == expected_first_billing
        if new_subscription_details.billable_unit == assets.ada_policy_id {
          new_subscription_details.billable_amount >= platform_details.min_utxo_cost_lovelace
        } else {
          new_subscription_details.billable_amount > 0
        }
      }
      // TODO is it possible to check if the merchant is signing here? and then OR with owner check as well
      Burn -> (amount == -1)?
    }
  }

  else(_) {
    fail
  }
}

// -- Test constants --

const test_owner =
  #"aabbcc00000000000000000000000000000000000000000000000001"

const test_merchant =
  #"aabbcc00000000000000000000000000000000000000000000000002"

const test_platform =
  #"aabbcc00000000000000000000000000000000000000000000000003"

const test_platform_pol =
  #"aabbcc00000000000000000000000000000000000000000000000004"

const test_script =
  #"aabbcc00000000000000000000000000000000000000000000000005"

const test_anchor_name: AssetName =
  #"000643b0537562"

const test_platform_token: AssetName =
  #"000643b0506c6174666f726d4665655363686564756c65"

// -- Test helpers --

fn test_range(lower: Int, upper: Int) -> Interval<Int> {
  Interval {
    lower_bound: IntervalBound { bound_type: Finite(lower), is_inclusive: True },
    upper_bound: IntervalBound {
      bound_type: Finite(upper),
      is_inclusive: False,
    },
  }
}

fn test_platform_ref() -> Input {
  Input(
    OutputReference(
      #"bb00000000000000000000000000000000000000000000000000000000000000",
      0,
    ),
    Output(
      Address(VerificationKey(test_platform), None),
      from_lovelace(2_000_000)
        |> add(test_platform_pol, test_platform_token, 1),
      InlineDatum(
        PlatformFeeSchedule {
          fee_percentage_basis_points: 50,
          platform_vk: test_platform,
          min_utxo_cost_lovelace: 2_000_000,
        },
      ),
      None,
    ),
  )
}

fn test_collect_ada_with(
  lock_until: Int,
  billable_amount: Int,
  schedule: BillingSchedule,
  now: Int,
  input_lovelace: Int,
  next_lock_until: Int,
  output_schedule: BillingSchedule,
) -> Bool {
  let datum =
    SubscriptionDetails {
      lock_until,
      billable_amount,
      billable_unit: #"",
      billable_unit_name: #"",
      merchant_vk: test_merchant,
      billing_schedule: schedule,
    }

  let platform_fee = math.max(50 * billable_amount / 1000, 2_000_000)
  let change = input_lovelace - platform_fee - billable_amount

  let anchor_ref =
    OutputReference(
      #"aa00000000000000000000000000000000000000000000000000000000000000",
      0,
    )

  let updated_datum =
    SubscriptionDetails {
      ..datum,
      lock_until: next_lock_until,
      billing_schedule: output_schedule,
    }

  let tx =
    Transaction {
      ..transaction.placeholder,
      inputs: [
        Input(
          anchor_ref,
          Output(
            Address(Script(test_script), None),
            from_lovelace(input_lovelace)
              |> add(test_script, test_anchor_name, 1),
            InlineDatum(datum),
            None,
          ),
        ),
      ],
      reference_inputs: [test_platform_ref()],
      outputs: [
        Output(
          Address(VerificationKey(test_platform), None),
          from_lovelace(platform_fee),
          NoDatum,
          None,
        ),
        Output(
          Address(VerificationKey(test_merchant), None),
          from_lovelace(billable_amount),
          NoDatum,
          None,
        ),
        Output(
          Address(Script(test_script), None),
          from_lovelace(change) |> add(test_script, test_anchor_name, 1),
          InlineDatum(updated_datum),
          None,
        ),
      ],
      validity_range: test_range(now, now + 180000),
    }

  subscriptor.spend(
    test_owner,
    test_platform_pol,
    None,
    CollectPayment(0),
    anchor_ref,
    tx,
  )
}

fn test_collect_ada(
  lock_until: Int,
  billable_amount: Int,
  schedule: BillingSchedule,
  now: Int,
  input_lovelace: Int,
  next_lock_until: Int,
) -> Bool {
  test_collect_ada_with(
    lock_until,
    billable_amount,
    schedule,
    now,
    input_lovelace,
    next_lock_until,
    schedule,
  )
}

// -- CollectPayment: happy-path billing schedules --

test collect_monthly_ada() {
  // Jan 1, 2024 → Feb 1, 2024
  test_collect_ada(
    1704067200000,
    10_000_000,
    Monthly,
    1704067201000,
    50_000_000,
    1706745600000,
  )
}

test collect_weekly_ada() {
  // Jan 1, 2024 → Jan 8, 2024
  test_collect_ada(
    1704067200000,
    10_000_000,
    Weekly,
    1704067201000,
    50_000_000,
    1704672000000,
  )
}

test collect_daily_ada() {
  // Jan 1, 2024 → Jan 2, 2024
  test_collect_ada(
    1704067200000,
    10_000_000,
    Daily,
    1704067201000,
    50_000_000,
    1704153600000,
  )
}

test collect_biweekly_ada() {
  // Jan 1, 2024 → Jan 15, 2024
  test_collect_ada(
    1704067200000,
    10_000_000,
    BiWeekly,
    1704067201000,
    50_000_000,
    1705276800000,
  )
}

test collect_every_5min_ada() {
  // lock_until + 300_000ms (5 minutes)
  test_collect_ada(
    1704067200000,
    10_000_000,
    EveryNMilliseconds(300000),
    1704067201000,
    50_000_000,
    1704067500000,
  )
}

test collect_monthly_feb_leap_year() {
  // Feb 1, 2024 → Mar 1, 2024 (leap year: Feb has 29 days)
  test_collect_ada(
    1706745600000,
    10_000_000,
    Monthly,
    1706745601000,
    50_000_000,
    1709251200000,
  )
}

// -- CollectPayment: failure cases --

test collect_before_lock_fails() fail {
  // now is 1ms before lock_until — collection not yet allowed
  test_collect_ada(
    1704067200000,
    10_000_000,
    Monthly,
    1704067199999,
    50_000_000,
    1706745600000,
  )
}

test collect_wrong_next_date_fails() fail {
  // Correct next date is Feb 1, but we pass Feb 2 (off by 1 day)
  test_collect_ada(
    1704067200000,
    10_000_000,
    Monthly,
    1704067201000,
    50_000_000,
    1706832000000,
  )
}

test collect_schedule_tampered_fails() fail {
  // Input datum says Monthly, output datum says Weekly
  test_collect_ada_with(
    1704067200000,
    10_000_000,
    Monthly,
    1704067201000,
    50_000_000,
    1706745600000,
    Weekly,
  )
}

// -- CollectPayment: nonzero output offset --

test collect_at_nonzero_offset() {
  // Monthly collection with 3 filler outputs before subscription outputs
  let lock_until = 1704067200000
  let now = lock_until + 1000
  let billable_amount = 10_000_000
  let input_lovelace = 50_000_000
  let next_lock_until = 1706745600000
  let platform_fee = 2_000_000
  let change = input_lovelace - platform_fee - billable_amount

  let datum =
    SubscriptionDetails {
      lock_until,
      billable_amount,
      billable_unit: #"",
      billable_unit_name: #"",
      merchant_vk: test_merchant,
      billing_schedule: Monthly,
    }

  let anchor_ref =
    OutputReference(
      #"aa00000000000000000000000000000000000000000000000000000000000000",
      0,
    )

  let filler =
    Output(
      Address(VerificationKey(test_merchant), None),
      from_lovelace(1_000_000),
      NoDatum,
      None,
    )

  let tx =
    Transaction {
      ..transaction.placeholder,
      inputs: [
        Input(
          anchor_ref,
          Output(
            Address(Script(test_script), None),
            from_lovelace(input_lovelace)
              |> add(test_script, test_anchor_name, 1),
            InlineDatum(datum),
            None,
          ),
        ),
      ],
      reference_inputs: [test_platform_ref()],
      outputs: [
        filler,
        filler,
        filler,
        Output(
          Address(VerificationKey(test_platform), None),
          from_lovelace(platform_fee),
          NoDatum,
          None,
        ),
        Output(
          Address(VerificationKey(test_merchant), None),
          from_lovelace(billable_amount),
          NoDatum,
          None,
        ),
        Output(
          Address(Script(test_script), None),
          from_lovelace(change) |> add(test_script, test_anchor_name, 1),
          InlineDatum(
            SubscriptionDetails { ..datum, lock_until: next_lock_until },
          ),
          None,
        ),
      ],
      validity_range: test_range(now, now + 180000),
    }

  subscriptor.spend(
    test_owner,
    test_platform_pol,
    None,
    CollectPayment(3),
    anchor_ref,
    tx,
  )
}

// -- MintAnchor tests --

test mint_monthly() {
  // Tx submitted Dec 25, 2024 12:00 UTC, 3-min window
  // Monthly from upper bound → Jan 1, 2025 00:00:00 UTC
  let lower = 1735128000000
  let upper = lower + 180000
  let expected_lock = 1735689600000

  let tx =
    Transaction {
      ..transaction.placeholder,
      outputs: [
        Output(
          Address(Script(test_script), None),
          from_lovelace(50_000_000)
            |> add(test_script, test_anchor_name, 1),
          InlineDatum(
            SubscriptionDetails {
              lock_until: expected_lock,
              billable_amount: 10_000_000,
              billable_unit: #"",
              billable_unit_name: #"",
              merchant_vk: test_merchant,
              billing_schedule: Monthly,
            },
          ),
          None,
        ),
      ],
      reference_inputs: [test_platform_ref()],
      mint: from_asset(test_script, test_anchor_name, 1),
      validity_range: test_range(lower, upper),
      extra_signatories: [test_owner],
    }

  subscriptor.mint(test_owner, test_platform_pol, MintAnchor, test_script, tx)
}

test mint_daily() {
  // Tx submitted Dec 25, 2024 12:00 UTC
  // Daily from upper bound → Dec 26, 2024 00:00:00 UTC
  let lower = 1735128000000
  let upper = lower + 180000
  let expected_lock = 1735171200000

  let tx =
    Transaction {
      ..transaction.placeholder,
      outputs: [
        Output(
          Address(Script(test_script), None),
          from_lovelace(50_000_000)
            |> add(test_script, test_anchor_name, 1),
          InlineDatum(
            SubscriptionDetails {
              lock_until: expected_lock,
              billable_amount: 10_000_000,
              billable_unit: #"",
              billable_unit_name: #"",
              merchant_vk: test_merchant,
              billing_schedule: Daily,
            },
          ),
          None,
        ),
      ],
      reference_inputs: [test_platform_ref()],
      mint: from_asset(test_script, test_anchor_name, 1),
      validity_range: test_range(lower, upper),
      extra_signatories: [test_owner],
    }

  subscriptor.mint(test_owner, test_platform_pol, MintAnchor, test_script, tx)
}

test mint_every_n_zero_fails() fail {
  // EveryNMilliseconds(0) should be rejected (n must be > 0)
  let lower = 1735128000000
  let upper = lower + 180000

  let tx =
    Transaction {
      ..transaction.placeholder,
      outputs: [
        Output(
          Address(Script(test_script), None),
          from_lovelace(50_000_000)
            |> add(test_script, test_anchor_name, 1),
          InlineDatum(
            SubscriptionDetails {
              lock_until: upper,
              billable_amount: 10_000_000,
              billable_unit: #"",
              billable_unit_name: #"",
              merchant_vk: test_merchant,
              billing_schedule: EveryNMilliseconds(0),
            },
          ),
          None,
        ),
      ],
      reference_inputs: [test_platform_ref()],
      mint: from_asset(test_script, test_anchor_name, 1),
      validity_range: test_range(lower, upper),
      extra_signatories: [test_owner],
    }

  subscriptor.mint(test_owner, test_platform_pol, MintAnchor, test_script, tx)
}

// -- Burn test --

test burn_succeeds() {
  let lower = 1704067200000

  let tx =
    Transaction {
      ..transaction.placeholder,
      mint: from_asset(test_script, test_anchor_name, -1),
      validity_range: test_range(lower, lower + 180000),
      extra_signatories: [test_owner],
    }

  subscriptor.mint(test_owner, test_platform_pol, Burn, test_script, tx)
}

// -- Withdraw tests --

test withdraw_succeeds() {
  let ref =
    OutputReference(
      #"cc00000000000000000000000000000000000000000000000000000000000000",
      0,
    )

  let tx =
    Transaction {
      ..transaction.placeholder,
      inputs: [
        Input(
          ref,
          Output(
            Address(Script(test_script), None),
            from_lovelace(10_000_000),
            NoDatum,
            None,
          ),
        ),
      ],
      extra_signatories: [test_owner],
    }

  subscriptor.spend(test_owner, test_platform_pol, None, Withdraw, ref, tx)
}

test withdraw_with_datum_blocked() fail {
  let ref =
    OutputReference(
      #"cc00000000000000000000000000000000000000000000000000000000000000",
      0,
    )

  let tx =
    Transaction {
      ..transaction.placeholder,
      inputs: [
        Input(
          ref,
          Output(
            Address(Script(test_script), None),
            from_lovelace(10_000_000),
            InlineDatum(
              SubscriptionDetails {
                lock_until: 1704067200000,
                billable_amount: 10_000_000,
                billable_unit: #"",
                billable_unit_name: #"",
                merchant_vk: test_merchant,
                billing_schedule: Monthly,
              },
            ),
            None,
          ),
        ),
      ],
      extra_signatories: [test_owner],
    }

  subscriptor.spend(test_owner, test_platform_pol, None, Withdraw, ref, tx)
}
