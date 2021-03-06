import
  strformat, strutils, sequtils, macros,
  constants, logging, errors, opcode_values, computation, vm/stack, ttmath

template run*(opcode: Opcode, computation: var BaseComputation) =
  # Hook for performing the actual VM execution
  computation.gasMeter.consumeGas(opcode.gasCost(computation), reason = $opcode.kind)
  opcode.runLogic(computation)

method logger*(opcode: Opcode): Logger =
  logging.getLogger(&"vm.opcode.{opcode.kind}")

method gasCost*(opcode: Opcode, computation: var BaseComputation): UInt256 =
  #if opcode.kind in VARIABLE_GAS_COST_OPS:
  #  opcode.gasCostHandler(computation)
  #else:
  opcode.gasCostConstant

template newOpcode*(kind: Op, gasCost: UInt256, logic: proc(computation: var BaseComputation)): Opcode =
  Opcode(kind: kind, gasCostConstant: gasCost, runLogic: logic)

template newOpcode*(kind: Op, gasHandler: proc(computation: var BaseComputation): UInt256, logic: proc(computation: var BaseComputation)): Opcode =
  Opcode(kind: kind, gasCostHandler: gasHandler, runLogic: logic)

method `$`*(opcode: Opcode): string =
  let gasCost = $opcode.gasCostConstant
  # if opcode.kind in VARIABLE_GAS_COST_OPS:
  #   "variable"
  # else:
  #   $opcode.gasCostConstant
  &"{opcode.kind}(0x{opcode.kind.int.toHex(2)}: {gasCost})"

macro initOpcodes*(spec: untyped): untyped =
  var value = ident("value")
  result = quote:
    block:
      var `value` = initTable[Op, Opcode]()

  for child in spec:
    var ops, gasCosts, handlers: seq[NimNode]
    if child.kind == nnkInfix and child[0].repr == "..":
      ops = @[]
      gasCosts = @[]
      handlers = @[]
      let first = child[1].repr.parseInt
      let last = child[2][0].repr.parseInt
      let op = child[2][1][1].repr
      for z in first .. last:
        ops.add(nnkDotExpr.newTree(ident("Op"), ident(op.replace("XX", $z))))
        gasCosts.add(child[3][0][0])
        handlers.add(ident(child[3][0][1].repr.replace("XX", $z)))
    else:
      ops = @[child[0]]
      gasCosts = @[child[1][0][0]]
      handlers = @[child[1][0][1]]
    for z in 0 ..< ops.len:
      let (op, gasCost, handler) = (ops[z], gasCosts[z], handlers[z])
      let opcode = if gasCost.repr[0].isLowerAscii():
        quote:
          `value`[`op`] = Opcode(kind: `op`, gasCostHandler: `gasCost`, runLogic: `handler`)
      else:
        quote:
          `value`[`op`] = Opcode(kind: `op`, gasCostConstant: `gasCost`, runLogic: `handler`)
      result[1].add(opcode)
  
  result[1].add(value)

