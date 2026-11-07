# minimal

This example was generated from these source files.

## `.espf.txt`

```xml
====================
MINIMAL EXAMPLE
====================

# espforge
  <project name="minimal" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals

# components

# devices

# services

```

## `src/app.rs`

```rust
#[allow(unused_variables)]
use crate::Context;

pub fn setup(ctx: &mut Context) {}

pub fn forever(ctx: &mut Context) {}

```
