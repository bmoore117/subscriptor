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

// Only the person who deployed the contract can mint or burn 
// anchors or spending tokens - which together form a CIP-68 pair
validator(ownerVk: VerificationKeyHash) {
  fn handle_subscription(rdmr: Action, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, purpose } =
      ctx

    expect tx.Mint(policy_id) =
      purpose

    let Transaction { inputs, mint, .. } =
      transaction

    expect [(asset_name, amount)] =
      mint
        |> value.from_minted_value
        |> value.tokens(policy_id)
        |> dict.to_list()

    let signed = list.has(transaction.extra_signatories, ownerVk)
    let cip68ReferencePrefixed =
      when bytearray.index_of(asset_name, #"000643b0") is {
        Some((0, _)) -> True
        _other -> False
      }

    let cip68NamesAndPolicyMatch = option.or_else(option.map(list.at(transaction.reference_inputs, 0), fn (input) {
      let inputAssetName = input.output.value.asset_name
      let inputPolicyId = input.output.value.policy_id
      bytearray.compare(inputPolicyId, policy_id) == Equal 
        && bytearray.compare(bytearray.concat(#"000de140", bytearray.drop(inputAssetName, 8)), asset_name) == Equal
    }), False)

    when rdmr is {
      MintAnchor -> {
        (amount == 1)? && signed? && cip68ReferencePrefixed?
      }
      MintSpendingToken -> {
        (amount == 1)? && signed? && cip68NamesAndPolicyMatch?
      }
      Burn ->
        (amount == -1)? && signed? && contained?
    }
  }
}

// Only the person who deployed the contract can unlock funds in it
validator(ownerVk: VerificationKeyHash) {
  fn redeem(_d: Data, _r: Data, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, .. } =
      ctx

    let Transaction { mint, .. } =
      transaction

    list.has(transaction.extra_signatories, ownerVk)
  }
}
