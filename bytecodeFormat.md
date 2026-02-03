# Bytecode Format Specification

## Overview

defines the binary layout and instruction encoding for the bytecode.

1. Main Function Pointer
2. Function Table Size
3. Constant Pool Offset/Pointer
4. Constant Pool Size
5. Instruction Stream Offset/Pointer
6. Function Table
7. Constant Pool
8. Instruction Stream

---

# File Layout

```
BytecodeFile {
  MainFuncPointer: 8 bytes
  FunctionTableSize: 8 bytes
  ConstantPoolPointer: 8 bytes
  ConstantPoolSize: 8 bytes
  InstructionStreamPointer: 8 bytes
  FunctionTable
  constPool
  instructions
}
```

---

# Function Table

```
FunctionTable: [
  [
    ptr,     // u64
    name     // string
  ],
  ...
]
```

---

# Constant Pool

Stores string constants.

```
constPool: [
  {[u8], [u8], ..., 0},
  ...
]
```

---

# Instruction Encoding

## Arithmetic Operations

| Instruction | op   | access mode | op      |
|-------------|------|-------------|---------|
|Add, Sub, Mul, Div, Mod | 1 | 0 | 0 |

Operands are taken from the stack.

---

# Push/Pop Instructions
| Instruction | op   | access mode | op      |
|-------------|------|-------------|---------|
|push i8      |1 byte|1 byte       |1/8 bytes|
|push i64     |1 byte|1 byte       |8 bytes  |
|push f64     |1 byte|1 byte       |8 bytes  |
|pop          |1 byte|0 byte       |8 bytes  |

# Func Call
| Instruction | op   | access mode | op      |
|-------------|------|-------------|---------|
|call         |1 byte|0 byte       |8 bytes  |
|ret          |1 byte|0 byte       |0 bytes  |

