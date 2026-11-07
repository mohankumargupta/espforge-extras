# i2c_example

This example was generated from these source files.

## `.espf.txt`

```xml
==================
I2C EXAMPLE
==================

# espforge
  <project name="i2c_example" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals
  <i2c id="i2c0" sda="6" scl="7" frequency="100kHz" />

# components
  <i2c_component id="i2c_tester" i2c="$i2c0" address="0x42" />

# devices

# services

```

## `src/app.rs`

```rust
#![allow(unused_variables)]

use crate::Context;

pub fn setup(ctx: &mut Context) {
    let logger = ctx.logger;
    let i2c = component!(ctx, i2c_tester);

    logger.info("I2C Example");

    let mut buffer = [0x00u8];
    let sent_byte = 0x03u8;
    // The address lives in `example.espf.txt`: this handle already knows it.
    match i2c.write_read(&[sent_byte], &mut buffer) {
        Ok(_) => {
            logger.info(format_args!("Sent {}", sent_byte));
            logger.info(format_args!("Received: {}", buffer[0]));
        }
        Err(_) => {
            logger.info("I2C transfer failed");
        }
    }
}

pub fn forever(ctx: &mut Context) {
    let delay = ctx.delay;
    delay.delay_ms(1000);
}

```
