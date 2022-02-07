# WAERGO

The "wrapped AERGO" token is the ARC1 version of the native AERGO token

<table>
  <tr><td>Name:</td><td>wrapped AERGO</td></tr>
  <tr><td>Symbol:</td><td>WAERGO</td></tr>
  <tr><td>Decimals:</td><td>18</td></tr>
  <tr><td>Address (testnet):</td><td>AmhEHnMcHvNXtW4nszzCvh4iLbV7BMgBkd4F1kn1jgzoAGW6oNqq</td></tr>
  <tr><td>Address (alphanet):</td><td>Amg7eGH6SJ3QBhM297sDfPPiAbgj6gFAeUmYHCtPRYvjmdvF5iXY</td></tr>
</table>

With this contract we can "convert" native AERGO tokens to its "wrapped"
version (WAERGO) in ARC1 format, as well as to convert back the 
wrapped tokens to the native ones (unwrap)

It makes it easier to develop DeFi contracts, as they only need to support
ARC1 tokens


## Wrapping and Unwrapping

Soon we may have apps to make the conversion easy, and signing via
the Aergo Connect

Probably the token swap apps will support the conversion

Sometimes the conversion will be automatic so we will not
even perceive


## Using the contract (for developers)

On the examples bellow we consider that `waergo` is a variable
containing the address of the WAERGO contract.

For use in the console:

```
export waergo=Am...
```

The address depends on the network being used.


## Wrap

Call the `wrap` function, sending the aergo tokens that should be wrapped.

On a contract:

```lua
contract.call.value(amount)(waergo, "wrap")
```

Your contract must implement the `tokensReceived()` function, that
will be called with details of the token conversion.

Example:

```lua
function tokensReceived(operator, from, amount)
  ...
end
```

## Wrap To

Wrap the native tokens and send the WAERGO to a destination address.

Call the `wrap_to` function, sending the aergo tokens that should be wrapped.

```lua
contract.call.value(amount)(waergo, "wrap_to", address)
```

If the destination is a contract, it must implement the
`tokensReceived()` interface.


## Unwrap

Call the `unwrap` function, informing the amount of tokens
that should be unwrapped.

On a contract, you can inform the payable function that will
receive the native tokens:

```lua
contract.call(waergo, "unwrap", amount, "receive_aergo")
```

If the contract has a default function marked as payable, then
there is no need to inform the function name.


## Unwrap To

Unwrap the WAERGO to native AERGO and send them to a destination
account.

On a contract:

If the destination is a normal account:

```lua
contract.call(waergo, "unwrap_to", amount, to)
```

If the destination is a contract, we can inform the
payable function that will receive the native tokens:

```lua
contract.call(waergo, "unwrap_to", amount, to, "receive_aergo")
```

If the destination contract has a default function marked as
payable, then there is no need to inform the function name.


## Transfer

As it follows the ARC1 standard, we can make transfers in the
same way as for any ARC1 token.

