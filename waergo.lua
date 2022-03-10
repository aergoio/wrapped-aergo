------------------------------------------------------------------------------
-- WAERGO ARC1 token extension
------------------------------------------------------------------------------

extensions["wrapped_aergo"] = true

function constructor()
  _init("wrapped AERGO", "WAERGO", 18)
end

local function _wrap(amount, to, ...)
  _typecheck(to, 'address')
  amount = _check_bignum(amount)

  -- mint WAERGO tokens

  contract.event("mint", to, bignum.tostring(amount))
  return _mint(to, amount, ...)
end

local function _unwrap(amount, from, to, recvFunc)
  _typecheck(from, 'address')
  if to ~= from then
    _typecheck(to, 'address')
  end
  amount = _check_bignum(amount)

  -- burn WAERGO tokens (from)

  contract.event("burn", from, bignum.tostring(amount), nil)
  _burn(from, amount)

  -- send AERGO tokens (to)

  if system.isContract(to) and recvFunc ~= nil then
    contract.call.value(amount)(to, recvFunc, from)
  else
    contract.send(to, amount)
  end
end

------------ Exported Functions ------------

-- Wrap sender's AERGO tokens into WAERGO
-- @type    call
-- @param   ...     addtional data, is sent unaltered in call to 'tokensReceived' on 'to'
-- @event   mint(from, amount)
function wrap(...)
  local to = system.getSender()
  local amount = bignum.number(system.getAmount())

  _wrap(amount, to, ...)
end

-- Wrap sender's AERGO tokens into WAERGO and transfer them to target 'to'
-- @type    call
-- @param   to      (address) a target address
-- @param   ...     addtional data, is sent unaltered in call to 'tokensReceived' on 'to'
-- @event   mint(to, amount)
function wrap_to(to, ...)
  local amount = bignum.number(system.getAmount())

  _wrap(amount, to, ...)
end

-- Unwrap sender's WAERGO tokens to native AERGO
-- @type    call
-- @param   amount   (ubig) the amount of tokens to unwrap
-- @param   recvFunc (string) if a contract, the name of the payable function to receive the AERGO
-- @event   burn(from, amount)
function unwrap(amount, recvFunc)
  local from = system.getSender()
  _unwrap(amount, from, from, recvFunc)
end

-- Unwrap sender's WAERGO tokens and send the native AERGO to target 'to'
-- @type    call
-- @param   amount   (ubig) the amount of tokens to unwrap
-- @param   to       (address) a target address
-- @param   recvFunc (string) if a contract, the name of the payable function to receive the AERGO
-- @event   burn(from, amount)
function unwrap_to(amount, to, recvFunc)
  local from = system.getSender()
  _unwrap(amount, from, to, recvFunc)
end

abi.payable(wrap, wrap_to)
abi.register(unwrap, unwrap_to)
