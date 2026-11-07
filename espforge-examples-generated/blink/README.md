# blink

This example was generated from these source files.

## `.espf.txt`

```xml
====================
BLINK EXAMPLE
====================

# espforge
  <project name="blink" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals
  <gpio id="gpio18" pin="18" direction="output" />

# components
  <led id="red_led" gpio="$gpio18" />

# devices

# services

```

## `src/app.rs`

```rust
use crate::Context;

pub fn setup(ctx: &mut Context) {
    ctx.logger.info("blink example");
}

pub fn forever(ctx: &mut Context) {
    let led = component!(ctx, red_led);
    led.toggle();
    ctx.delay.delay_ms(1000);
}

```
