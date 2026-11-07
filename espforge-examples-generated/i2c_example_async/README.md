# i2c_example_async

This example was generated from these source files.

## `.espf.txt`

```xml
==================
I2C EXAMPLE (ASYNC)
==================

# espforge
  <project name="i2c_example_async" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

# peripherals
  <i2c id="i2c0" sda="6" scl="7" frequency="100kHz" />

# components
  <i2c_component id="i2c0" i2c="$i2c0" address="0x42" />

# devices

# services

```

## `src/app.rs`

```rust
#![allow(unused_variables)]

use crate::Context;
use embassy_executor::Spawner;

#[embassy_executor::task]
async fn transfer_task(ctx: &'static Context) {
    let i2c = component!(ctx, i2c0);
    let logger = ctx.logger;
    let mut buffer = [0x00u8];
    let sent_byte = 0x03u8;
    // The address lives in `example.espf.txt`: this handle already knows it.
    match i2c.write_read(&[sent_byte], &mut buffer).await {
        Ok(_) => {
            logger.info(format_args!("Sent {}", sent_byte));
            logger.info(format_args!("Received: {}", buffer[0]));
        },
        Err(_) => logger.info("i2c transfer failed"),
     }
}

pub async fn setup(ctx: &'static Context, spawner: Spawner) {
    spawner.spawn(transfer_task(ctx).expect("transfer_task spawn failed"));
}

pub async fn forever(ctx: &'static Context) {
    // Work happens in the spawned tasks; the main loop just yields.
    ctx.delay.delay_ms(1000).await;
}

```
