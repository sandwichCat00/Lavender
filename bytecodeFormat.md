# Bytecode Format Specification

## Overview

defines the binary layout and instruction encoding for the bytecode.

1. Function Table Size
2. Function Table
3. Main Function Pointer
4. Constant Pool Size
5. Constant Pool
6. Instructions

---

# File Layout

```
BytecodeFile {
  FunctionTableSize: 8 bytes
  FunctionTable
  MainFuncPointer: 8 bytes 
  ConstantPoolSize: 8 bytes
  ConstantPool
  instructions
}
```

---

# MainFuncPointer

Indexing starts 1.
0 MainFuncPointer indicates no main function in class file.

---

# Function Table

```
FunctionTable: [
  [
    ptr,     // u64
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

## Operations

| Instruction | op   | access mode | op      |
|-------------|------|-------------|---------|
|Add, Sub, Mul, Div, Mod | 1 | 0 | 0 |
|Eql, AddEql, SubEql, MulEql, DivEql, ModEql | 1 | 0 | 0 |
|IsEql, IsNotEql, IsGtrEql, IsLesEql, IsGtr, IsLes | 1 | 0 | 0 |

Operands are taken from the stack.

---

# Push/Pop Instructions
| Instruction | op   | access mode | op      |
|-------------|------|-------------|---------|
|push int     |1 byte|1 byte       |8 bytes  |
|push str     |1 byte|1 byte       |8 bytes  |
|push float   |1 byte|1 byte       |8 bytes  |
|pop          |1 byte|0 byte       |8 bytes  |

# Func Call
| Instruction | op   | access mode | op      |
|-------------|------|-------------|---------|
|call         |1 byte|0 byte       |8 bytes  |
|ret          |1 byte|0 byte       |0 bytes  |

