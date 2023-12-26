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
  Mint
  Burn
}

// Only the person who deployed the contract can mint or burn 
// things that start with the CIP-68 reference token asset_name
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

    expect Some((0, _)) = 
      bytearray.index_of(asset_name, #"000643b0")

    expect True = 
      list.has(transaction.extra_signatories, ownerVk)

    when rdmr is {
      Mint -> {
        amount == 1
      }
      Burn ->
        amount == -1
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
