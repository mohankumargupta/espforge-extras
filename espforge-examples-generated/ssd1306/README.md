# ssd1306

This example was generated from these source files.

## `.espf.txt`

```xml
==================
SSD1306 OLED EXAMPLE
==================

# espforge
  <project name="ssd1306" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals
  <i2c id="i2c0" sda="6" scl="7" frequency="400kHz" />

# components
  <i2c_component id="oled_bus" i2c="$i2c0" address="0x3C" />

# devices
  <ssd1306 id="oled" i2c_component="$oled_bus" size="128x64" />

# services

```

## `src/app.rs`

```rust
#![allow(unused_variables)]

use crate::Context;
use embedded_graphics::{
    mono_font::{MonoTextStyle, ascii::FONT_6X10},
    pixelcolor::BinaryColor,
    prelude::*,
    primitives::{Circle, PrimitiveStyle},
    text::Text,
};

pub fn setup(ctx: &mut Context) {
    let logger = ctx.logger;
    logger.info("SSD1306 OLED example");

    let oled = device!(ctx, oled);
    let text_style = MonoTextStyle::new(&FONT_6X10, BinaryColor::On);

    // The panel keeps a framebuffer; draw calls only change it.
    Circle::new(Point::new(4, 4), 24)
        .into_styled(PrimitiveStyle::with_stroke(BinaryColor::On, 1))
        .draw(oled)
        .ok();

    Text::new("ESPFORGE", Point::new(36, 20), text_style)
        .draw(oled)
        .ok();

    // Push the framebuffer to the panel.
    oled.flush().ok();
}

pub fn forever(ctx: &mut Context) {
    let delay = ctx.delay;
    delay.delay_ms(1000);
}

```
