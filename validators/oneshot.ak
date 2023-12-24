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
        |> value.tokens(policy_id)
        |> dict.to_list()

    expect Some(0, _) = 
      bytearray.index_of(asset_name, #"000643b0")

    expect True = 
      list.has(context.transaction.extra_signatories, ownerVk)

    when rdmr is {
      Mint -> {
        amount == 1
      }
      Burn ->
        amount == -1
    }
  }
}

validator(token_name: ByteArray, policy_id: ByteArray) {
  fn redeem(_d: Data, _r: Data, ctx: ScriptContext) -> Bool {
    let ScriptContext { transaction, .. } =
      ctx

    let Transaction { mint, .. } =
      transaction

    expect [(asset_name, amount)] =
      mint
        |> value.tokens(policy_id)
        |> dict.to_list()

    amount == -1 && asset_name == token_name
  }
}
