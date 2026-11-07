# blink_async

This example was generated from these source files.

## `.espf.txt`

```xml
====================
ASYNC BLINK EXAMPLE
====================

# espforge
  <project name="blink_async" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

# peripherals
  <gpio id="gpio18" pin="18" direction="output" />

# components
  <led id="red_led" gpio="$gpio18" />

# devices

# services

```

## `src/app.rs`

```rust
use crate::{component, Context};
use embassy_executor::Spawner;

pub async fn setup(ctx: &'static Context, _spawner: Spawner) {
    ctx.logger.info("blink async example");
}

pub async fn forever(ctx: &'static Context) {
    let led = component!(ctx, red_led);
    led.toggle();
    ctx.delay.delay_ms(1000).await;
}

```
