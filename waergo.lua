------------------------------------------------------------------------------
-- Aergo Standard Token Interface (Proposal) - 20190731
------------------------------------------------------------------------------

-- A internal type check function
-- @type internal
-- @param x variable to check
-- @param t (string) expected type
local function _typecheck(x, t)
  if (x and t == 'address') then
    assert(type(x) == 'string', "address must be string type")
    -- check address length
    assert(52 == #x, string.format("invalid address length: %s (%s)", x, #x))
    -- check character
    local invalidChar = string.match(x, '[^123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]')
    assert(nil == invalidChar, string.format("invalid address format: %s contains invalid char %s", x, invalidChar or 'nil'))
  elseif (x and t == 'ubig') then
    -- check unsigned bignum
    assert(bignum.isbignum(x), string.format("invalid type: %s != %s", type(x), t))
    assert(x >= bignum.number(0), string.format("%s must be positive number", bignum.tostring(x)))
  else
    -- check default lua types
    assert(type(x) == t, string.format("invalid type: %s != %s", type(x), t or 'nil'))
  end
end

address0 = '1111111111111111111111111111111111111111111111111111'

state.var {
  _balances = state.map(), -- address -> unsigned_bignum
  _operators = state.map(), -- address/address -> bool

  _totalSupply = state.value(),
  _name = state.value(),
  _symbol = state.value(),
  _decimals = state.value(),
}

local function _callTokensReceived(from, to, value, ...)
  if to ~= address0 and system.isContract(to) then
    contract.call(to, "tokensReceived", system.getSender(), from, value, ...)
  end
end

local function _transfer(from, to, value, ...)
  _typecheck(from, 'address')
  _typecheck(to, 'address')
  _typecheck(value, 'ubig')

  assert(_balances[from] and _balances[from] >= value, "not enough balance")

  _balances[from] = _balances[from] - value
  _balances[to] = (_balances[to] or bignum.number(0)) + value

  _callTokensReceived(from, to, value, ...)

  contract.event("transfer", from, to, value)
end

--[[
local function _mint(to, value, ...)
  _typecheck(to, 'address')
  _typecheck(value, 'ubig')

  _totalSupply:set((_totalSupply:get() or bignum.number(0)) + value)
  _balances[to] = (_balances[to] or bignum.number(0)) + value

  _callTokensReceived(address0, to, value, ...)

  contract.event("transfer", address0, to, value)
end

local function _burn(from, value)
  _typecheck(from, 'address')
  _typecheck(value, 'ubig')

  assert(_balances[from] and _balances[from] >= value, "not enough balance")

  _totalSupply:set(_totalSupply:get() - value)
  _balances[from] = _balances[from] - value

  contract.event("transfer", from, address0, value)
end
]]

local function _wrap(value, from, to, ...)
  _typecheck(value, 'ubig')
  _typecheck(from, 'address')
  if to ~= from then
    _typecheck(to, 'address')
  end

  _totalSupply:set((_totalSupply:get() or bignum.number(0)) + value)
  _balances[to] = (_balances[to] or bignum.number(0)) + value

  _callTokensReceived(from, to, value, ...)

  --contract.event("transfer", address0, to, value)
  contract.event("wrap", from, value)
  if to ~= from then
    contract.event("transfer", from, to, value)
  end
end

local function _unwrap(value, from, to, recvFunc)
  _typecheck(value, 'ubig')
  _typecheck(from, 'address')
  if to ~= from then
    _typecheck(to, 'address')
  end

  assert(_balances[from] and _balances[from] >= value, "not enough balance")

  _totalSupply:set(_totalSupply:get() - value)
  _balances[from] = _balances[from] - value

  if system.isContract(to) then
    contract.call.value(value)(to, recvFunc, from)
  else
    contract.send(to, value)
  end

  --contract.event("transfer", from, address0, value)
  contract.event("unwrap", from, value)
end

function constructor()
  _name:set("wrapped AERGO")
  _symbol:set("WAERGO")
  _decimals:set(18)
  _totalSupply:set(bignum.number(0))
end

------------  Main Functions ------------

-- Get a total token supply.
-- @type    query
-- @return  (ubig) total supply of this token
function totalSupply()
  return _totalSupply:get()
end

-- Get a token name
-- @type    query
-- @return  (string) name of this token
function name()
  return _name:get()
end

-- Get a token symbol
-- @type    query
-- @return  (string) symbol of this token
function symbol()
  return _symbol:get()
end

-- Get a token decimals
-- @type    query
-- @return  (number) decimals of this token
function decimals()
  return _decimals:get()
end

-- Get a balance of an owner.
-- @type    query
-- @param   owner  (address) a target address
-- @return  (ubig) balance of owner
function balanceOf(owner)
  return _balances[owner] or bignum.number(0)
end

-- Transfer sender's token to target 'to'
-- @type    call
-- @param   to      (address) a target address
-- @param   value   (ubig) an amount of token to send
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   transfer(from, to, value)
function transfer(to, value, ...)
  _transfer(system.getSender(), to, value, ...)
end

-- Get allowance from owner to spender
-- @type    query
-- @param   owner       (address) owner's address
-- @param   operator    (address) allowed address
-- @return  (bool) true/false
function isApprovedForAll(owner, operator)
  return (owner == operator) or (_operators[owner.."/".. operator] == true)
end

-- Allow operator to use all sender's token
-- @type    call
-- @param   operator  (address) a operator's address
-- @param   approved  (boolean) true/false
-- @event   approve(owner, operator, approved)
function setApprovalForAll(operator, approved)
  _typecheck(operator, 'address')
  _typecheck(approved, 'boolean')
  assert(system.getSender() ~= operator, "cannot set approve self as operator")

  _operators[system.getSender().."/".. operator] = approved

  contract.event("approve", system.getSender(), operator, approved)
end

-- Transfer 'from's token to target 'to'.
-- Tx sender have to be approved to spend from 'from'
-- @type    call
-- @param   from    (address) a sender's address
-- @param   to      (address) a receiver's address
-- @param   value   (ubig) an amount of token to send
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   transfer(from, to, value)
function transferFrom(from, to, value, ...)
  assert(isApprovedForAll(from, system.getSender()), "caller is not approved for holder")

  _transfer(from, to, value, ...)
end

-- Wrap sender's AERGO tokens into WAERGO
-- @type    call
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   wrap(from, value)
function wrap(...)
  local from = system.getSender()
  local amount = bignum.number(system.getAmount())

  _wrap(amount, from, from, ...)
end

-- Wrap sender's AERGO tokens into WAERGO and transfer them to target 'to'
-- @type    call
-- @param   to      (address) a target address
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   wrap(from, value)
-- @event   transfer(from, to, value)
function wrap_to(to, ...)
  local from = system.getSender()
  local amount = bignum.number(system.getAmount())

  _wrap(amount, from, to, ...)
end

-- Unwrap sender's WAERGO tokens to native AERGO
-- @type    call
-- @param   amount   (ubig) the amount of tokens to unwrap
-- @param   recvFunc (string) if a contract, the name of the payable function to receive the AERGO
-- @event   unwrap(from, value)
function unwrap(amount, recvFunc)
  local from = system.getSender()
  _unwrap(amount, from, from, recvFunc)
end

-- Unwrap sender's WAERGO tokens and send the native AERGO to target 'to'
-- @type    call
-- @param   amount   (ubig) the amount of tokens to unwrap
-- @param   to       (address) a target address
-- @param   recvFunc (string) if a contract, the name of the payable function to receive the AERGO
-- @event   unwrap(from, value)
function unwrap_to(amount, to, recvFunc)
  local from = system.getSender()
  _unwrap(amount, from, to, recvFunc)
end

abi.payable(wrap, wrap_to)
abi.register(transfer, transferFrom, setApprovalForAll, unwrap, unwrap_to)
abi.register_view(name, symbol, decimals, totalSupply, balanceOf, isApprovedForAll)
