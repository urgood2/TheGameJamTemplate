-- bit_compat.lua
if not bit then
  ---@diagnostic disable-next-line: duplicate-set-field
  bit = {}
  bit.bor  = bit.bor  or function(a, b) return a | b end
  bit.band = bit.band or function(a, b) return a & b end
  bit.bxor = bit.bxor or function(a, b) return a ~ b end
  bit.bnot = bit.bnot or function(a) return ~a end
  bit.lshift = bit.lshift or function(a, b) return a << b end
  bit.rshift = bit.rshift or function(a, b) return a >> b end
end
