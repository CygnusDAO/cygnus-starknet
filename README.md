# cygnus-starknet

# All contracts follow this structure:

1. Imports
2. Events
3. Storage
4. Constructor
5. External Functions (Implementation)
6. Internal Functions
# cygnus-starknet-cairo1


# Note

We commented out the tests on this repo until we can run them against a forked state.
This is because these contracts use strategies such as depositing usdc on zklend contracts, etc. which 
we cannot replicate with the current version of snforge. To verify tests, use the following repository which 
is the same but does not use `after_deposit` or `before_withdraw` hooks:

https://github.com/swan-of-bodom/cygnus-starknet-dev
