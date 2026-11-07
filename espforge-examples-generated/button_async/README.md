# button_async

This example was generated from these source files.

## `.espf.txt`

```xml
======================
ASYNC BUTTON EXAMPLE

A button task waits (edge-triggered, no polling) for the button to be pressed
and signals a cross-task `Signal`. The `forever` task waits on that signal and
toggles an LED each time the button is pressed.
======================

# espforge
  <project name="button_async" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

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

use crate::{Context};
use embassy_executor::Spawner;

// Cross-task signal async inter-task communication. Producer signals; consumer waits.
crate::signal!(BUTTON_PRESSED);

/// Spawned embassy task: waits for the button (edge-triggered) and
/// signals the LED task to toggle. Runs for the lifetime of the firmware.
#[embassy_executor::task]
async fn button_task(ctx: &'static Context) {
    loop {
        ctx.components.button.wait_for_pressed().await;
        BUTTON_PRESSED.signal(());
    }
}

/// Runs once at startup. Spawn the button-watching task.
pub async fn setup(ctx: &'static Context, spawner: Spawner) {
    spawner.spawn(button_task(ctx).unwrap());
}

/// Per-tick loop. Waits for a press signal, toggles the LED, then debounces.
pub async fn forever(ctx: &'static Context) {
    BUTTON_PRESSED.wait().await;
    ctx.components.red_led.toggle();
    // Debounce: ignore further presses for a short window.
    ctx.delay.delay_ms(100).await;
}

```
