package mempool

import (
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/core/types"
)

func BasicValidate(tx *types.Transaction, chainID *big.Int) error {
	if tx == nil { return errors.New("nil transaction") }
	if chainID == nil || chainID.Sign() <= 0 { return errors.New("invalid chain id") }
	if tx.Gas() == 0 { return errors.New("zero gas") }
	if tx.GasPrice() == nil || tx.GasPrice().Sign() < 0 { return errors.New("invalid gas price") }
	return nil
}
