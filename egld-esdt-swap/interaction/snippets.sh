ALICE="/home/elrond/elrond-sdk/erdpy/testnet/wallets/users/alice.pem"
BOB="/home/elrond/elrond-sdk/erdpy/testnet/wallets/users/bob.pem"
ADDRESS=$(erdpy data load --key=address-testnet)
DEPLOY_TRANSACTION=$(erdpy data load --key=deployTransaction-testnet)
PROXY=http://localhost:7950
CHAIN_ID=local-testnet

ESDT_SYSTEM_SC_ADDRESS=erd1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls8a5w6u

deploy() {
    ######################################################################
    ############################ Update after issue ######################
    ######################################################################
    WRAPPED_EGLD_TOKEN_ID=0x

    erdpy --verbose contract deploy --project=${PROJECT} --recall-nonce --pem=${ALICE} --gas-limit=100000000 --arguments ${WRAPPED_EGLD_TOKEN_ID} --send --outfile="deploy-testnet.interaction.json" --proxy=${PROXY} --chain=${CHAIN_ID} || return

    TRANSACTION=$(erdpy data parse --file="deploy-testnet.interaction.json" --expression="data['emitted_tx']['hash']")
    ADDRESS=$(erdpy data parse --file="deploy-testnet.interaction.json" --expression="data['emitted_tx']['address']")

    erdpy data store --key=address-testnet --value=${ADDRESS}
    erdpy data store --key=deployTransaction-testnet --value=${TRANSACTION}

    echo ""
    echo "Smart contract address: ${ADDRESS}"
}

upgrade() {
    erdpy --verbose contract upgrade ${ADDRESS} --project=${PROJECT} --recall-nonce --pem=${ALICE} --gas-limit=100000000 --send --outfile="upgrade.json" --proxy=${PROXY} --chain=${CHAIN_ID} || return
}

issueWrappedEgld() {
    TOKEN_DISPLAY_NAME=0x5772617070656445676c64  # "WrappedEgld"
    TOKEN_TICKER=0x5745474c44  # "WEGLD"
    INITIAL_SUPPLY=0x01 # 1
    NR_DECIMALS=0x12 # 18
    CAN_ADD_SPECIAL_ROLES=0x63616e4164645370656369616c526f6c6573 # "canAddSpecialRoles"
    TRUE=0x74727565 # "true"

    erdpy --verbose contract call ${ESDT_SYSTEM_SC_ADDRESS} --recall-nonce --pem=${ALICE} --gas-limit=60000000 --value=5000000000000000000 --function="issue" --arguments ${TOKEN_DISPLAY_NAME} ${TOKEN_TICKER} ${INITIAL_SUPPLY} ${NR_DECIMALS} ${CAN_ADD_SPECIAL_ROLES} ${TRUE} --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

setLocalRoles() {
    LOCAL_MINT_ROLE=0x45534454526f6c654c6f63616c4d696e74 # "ESDTRoleLocalMint"
    LOCAL_BURN_ROLE=0x45534454526f6c654c6f63616c4275726e # "ESDTRoleLocalBurn"

    erdpy --verbose contract call ${ESDT_SYSTEM_SC_ADDRESS} --recall-nonce --pem=${ALICE} --gas-limit=60000000 --function="setSpecialRole" --arguments ${WRAPPED_EGLD_TOKEN_ID} ${ADDRESS} ${LOCAL_MINT_ROLE} ${LOCAL_BURN_ROLE} --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

wrapEgldBob() {
    erdpy --verbose contract call ${ADDRESS} --recall-nonce --pem=${BOB} --gas-limit=10000000 --value=1000 --function="wrapEgld" --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

unwrapEgldBob() {
    UNWRAP_EGLD_ENDPOINT=0x756e7772617045676c64 # "unwrapEgld"
    UNWRAP_AMOUNT=0x05

    getWrappedEgldTokenIdentifier
    erdpy --verbose contract call ${ADDRESS} --recall-nonce --pem=${BOB} --gas-limit=10000000 --function="ESDTTransfer" --arguments ${TOKEN_IDENTIFIER} ${UNWRAP_AMOUNT} ${UNWRAP_EGLD_ENDPOINT} --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

# views

getWrappedEgldTokenIdentifier() {
    local QUERY_OUTPUT=$(erdpy --verbose contract query ${ADDRESS} --function="getWrappedEgldTokenId" --proxy=${PROXY})
    TOKEN_IDENTIFIER=0x$(jq -r '.[0] .hex' <<< "${QUERY_OUTPUT}")
    echo "Wrapped eGLD token identifier: ${TOKEN_IDENTIFIER}"
}

getLockedEgldBalance() {
    erdpy --verbose contract query ${ADDRESS} --function="getLockedEgldBalance" --proxy=${PROXY}
}
