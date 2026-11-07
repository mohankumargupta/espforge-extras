# ili9341

This example was generated from these source files.

## `.espf.txt`

```xml
==================
ILI9341 TFT EXAMPLE
==================

# espforge
  <project name="ili9341" />
  <chip type="esp32c3" />
  <runtime type="blocking" />

# peripherals
  <spi id="spi2" sclk="8" mosi="7" mode="0" frequency="40000kHz" />
  <gpio id="gpio4" pin="4" direction="output" />
  <gpio id="gpio5" pin="5" direction="output" />
  <gpio id="gpio6" pin="6" direction="output" />

# components
  <spi_component id="tft_bus" spi="$spi2" cs="9" />

# devices
  <ili9341 id="tft" spi_component="$tft_bus" dc="$gpio4" reset="$gpio5" backlight="$gpio6" rotation="90" />

# services

```

## `src/app.rs`

```rust
#![allow(unused_variables)]

use crate::Context;
use embedded_graphics::{
    mono_font::{MonoTextStyle, ascii::FONT_9X18_BOLD},
    pixelcolor::Rgb565,
    prelude::*,
    primitives::{PrimitiveStyle, Rectangle},
    text::Text,
};

pub fn setup(ctx: &mut Context) {
    let logger = ctx.logger;
    logger.info("ILI9341 TFT example");

    // Landscape orientation: 320x240.
    let tft = device!(ctx, tft);
    Rectangle::new(Point::zero(), Size::new(320, 240))
        .into_styled(PrimitiveStyle::with_fill(Rgb565::new(0, 0, 20)))
        .draw(tft)
        .ok();

    let title_style = MonoTextStyle::new(&FONT_9X18_BOLD, Rgb565::YELLOW);
    Text::new("ESPFORGE ILI9341", Point::new(20, 40), title_style)
        .draw(tft)
        .ok();
}

pub fn forever(ctx: &mut Context) {
    let delay = ctx.delay;
    delay.delay_ms(1000);
}

```
