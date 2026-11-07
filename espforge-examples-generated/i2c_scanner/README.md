# i2c_scanner

This example was generated from these source files.

## `.espf.txt`

```xml
==================
I2C SCANNER
==================

# espforge
  <project name="i2c_scanner" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals
  <i2c id="i2c0" sda="6" scl="7" frequency="100kHz" />

# components
  <i2c_component id="i2c0" i2c="$i2c0" />

# devices


# services



```

## `src/app.rs`

```rust
use crate::{Context};

pub fn setup(ctx: &mut Context) {
    let logger = ctx.logger;
    let delay = ctx.delay;
    let i2c = component!(ctx, i2c0);

    logger.info("I2C Scanner Example");

    // Scan addresses 1 to 127. Try a 0-byte write to each address; if it ACKs
    // there is a device there. `I2cBus<Blocking>` exposes the idiomatic
    // `write` helper (design §20.5); the underlying bus is also reachable via
    // `bus()`.
    for address in 1..127 {
        match i2c.write(address, &[]) {
            Ok(_) => {
                logger.info(format_args!("Found device at address 0x{:02x}", address));
            }
            Err(_) => {}
        }
        delay.delay_ms(10);
    }

    logger.info("Scan complete");
}

pub fn forever(ctx: &mut Context) {
    ctx.delay.delay_ms(1000);
}

```
