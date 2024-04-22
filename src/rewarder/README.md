The only contract that can mint new CYG into existence. 

Called by `borrowable.cairo` for all LP borrowers and USDC depositors.

1. LP Depositors - Called after any **borrow, repay or liquidation.**

2. USDC Depositors - Called after any USDC **deposit or redeem** to update the user's position and thus CYG rewards shares

