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

function _check_bignum(x)
  if type(x) == 'string' then
    assert(string.match(x, '[^0-9]') == nil, "amount contains invalid character")
    x = bignum.number(x)
  end
  _typecheck(x, 'ubig')
  return x
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

local function _callTokensReceived(from, to, amount, ...)
  if to ~= address0 and system.isContract(to) then
    contract.call(to, "tokensReceived", system.getSender(), from, amount, ...)
  end
end

local function _transfer(from, to, amount, ...)
  _typecheck(from, 'address')
  _typecheck(to, 'address')
  amount = _check_bignum(amount)

  assert(_balances[from] and _balances[from] >= amount, "not enough balance")

  _balances[from] = _balances[from] - amount
  _balances[to] = (_balances[to] or bignum.number(0)) + amount

  _callTokensReceived(from, to, amount, ...)

  contract.event("transfer", from, to, bignum.tostring(amount))
end

--[[
local function _mint(to, amount, ...)
  _typecheck(to, 'address')
  amount = _check_bignum(amount)

  _totalSupply:set((_totalSupply:get() or bignum.number(0)) + amount)
  _balances[to] = (_balances[to] or bignum.number(0)) + amount

  _callTokensReceived(address0, to, amount, ...)

  contract.event("transfer", address0, to, amount)
end

local function _burn(from, amount)
  _typecheck(from, 'address')
  amount = _check_bignum(amount)

  assert(_balances[from] and _balances[from] >= amount, "not enough balance")

  _totalSupply:set(_totalSupply:get() - amount)
  _balances[from] = _balances[from] - amount

  contract.event("transfer", from, address0, amount)
end
]]

local function _wrap(amount, from, to, ...)
  amount = _check_bignum(amount)
  _typecheck(from, 'address')
  if to ~= from then
    _typecheck(to, 'address')
  end

  _totalSupply:set((_totalSupply:get() or bignum.number(0)) + amount)
  _balances[to] = (_balances[to] or bignum.number(0)) + amount

  _callTokensReceived(from, to, amount, ...)

  contract.event("wrap", to, bignum.tostring(amount))
end

local function _unwrap(amount, from, to, recvFunc)
  amount = _check_bignum(amount)
  _typecheck(from, 'address')
  if to ~= from then
    _typecheck(to, 'address')
  end

  assert(_balances[from] and _balances[from] >= amount, "not enough balance")

  _totalSupply:set(_totalSupply:get() - amount)
  _balances[from] = _balances[from] - amount

  if system.isContract(to) then
    contract.call.value(amount)(to, recvFunc, from)
  else
    contract.send(to, amount)
  end

  contract.event("unwrap", from, bignum.tostring(amount))
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
  if owner == nil or owner == '' then
    owner = system.getSender()
  end
  return _balances[owner] or bignum.number(0)
end

-- Transfer sender's token to target 'to'
-- @type    call
-- @param   to      (address) a target address
-- @param   amount  (ubig) an amount of token to send
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   transfer(from, to, amount)
function transfer(to, amount, ...)
  _transfer(system.getSender(), to, amount, ...)
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
-- @param   amount  (ubig) an amount of token to send
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   transfer(from, to, amount)
function transferFrom(from, to, amount, ...)
  assert(isApprovedForAll(from, system.getSender()), "caller is not approved for holder")

  _transfer(from, to, amount, ...)
end

-- Wrap sender's AERGO tokens into WAERGO
-- @type    call
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   wrap(from, amount)
function wrap(...)
  local from = system.getSender()
  local amount = bignum.number(system.getAmount())

  _wrap(amount, from, from, ...)
end

-- Wrap sender's AERGO tokens into WAERGO and transfer them to target 'to'
-- @type    call
-- @param   to      (address) a target address
-- @param   ...     addtional data, MUST be sent unaltered in call to 'tokensReceived' on 'to'
-- @event   wrap(from, amount)
-- @event   transfer(from, to, amount)
function wrap_to(to, ...)
  local from = system.getSender()
  local amount = bignum.number(system.getAmount())

  _wrap(amount, from, to, ...)
end

-- Unwrap sender's WAERGO tokens to native AERGO
-- @type    call
-- @param   amount   (ubig) the amount of tokens to unwrap
-- @param   recvFunc (string) if a contract, the name of the payable function to receive the AERGO
-- @event   unwrap(from, amount)
function unwrap(amount, recvFunc)
  local from = system.getSender()
  _unwrap(amount, from, from, recvFunc)
end

-- Unwrap sender's WAERGO tokens and send the native AERGO to target 'to'
-- @type    call
-- @param   amount   (ubig) the amount of tokens to unwrap
-- @param   to       (address) a target address
-- @param   recvFunc (string) if a contract, the name of the payable function to receive the AERGO
-- @event   unwrap(from, amount)
function unwrap_to(amount, to, recvFunc)
  local from = system.getSender()
  _unwrap(amount, from, to, recvFunc)
end

abi.payable(wrap, wrap_to)
abi.register(transfer, transferFrom, setApprovalForAll, unwrap, unwrap_to)
abi.register_view(name, symbol, decimals, totalSupply, balanceOf, isApprovedForAll)
