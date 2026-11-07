# button

This example was generated from these source files.

## `.espf.txt`

```xml
====================
BUTTON EXAMPLE
====================

# espforge
  <project name="button" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals
  <gpio id="gpio7" pin="7" direction="output" />
  <gpio id="gpio9" pin="9" direction="input" />

# components
  <led id="red_led" gpio="$gpio7" active_low="false" />
  <button id="button" gpio="$gpio9" pull_up="true" />

# devices

# services 



```

## `src/app.rs`

```rust
#[warn(unused_variables)]

use crate::{Context};

pub fn setup(ctx: &mut Context) {
  let logger = ctx.logger;
  logger.info("Button Example");
}

pub fn forever(ctx: &mut Context) {
    let delay = ctx.delay;
    let button = component!(ctx, button);
    let led = component!(ctx, red_led);
    
    if button.is_pressed() {
        led.toggle();
        delay.delay_ms(100);
    }
    
    delay.delay_ms(100);
}

```
