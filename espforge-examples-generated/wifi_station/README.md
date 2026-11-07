# wifi_station

This example was generated from these source files.

## `.espf.txt`

```xml
====================
WIFI STATION EXAMPLE

Connects to an existing Wi-Fi network (an open one here, so it works in
Wokwi), then prints the DHCP address the network handed out. The network stack
this brings up is what the HTTP and HTTPS client services connect through.
====================

# espforge
  <project name="wifi_station" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

# peripherals
  <wifi id="radio" />

# components
  <wifi_station id="home" wifi="$radio" ssid="Wokwi-GUEST" auth="open" />

# devices

# services

```

## `src/app.rs`

```rust
use crate::{component, Context};
use embassy_executor::Spawner;

/// Runs once at startup: wait for the association and DHCP, then report the
/// address.
pub async fn setup(ctx: &'static Context, _spawner: Spawner) {
    let logger = ctx.logger;
    let station = component!(ctx, home);

    logger.info("Wi-Fi example: connecting...");
    station.wait_connected().await;

    match station.stack().config_v4() {
        Some(config) => logger.info(format_args!("Connected, IP address: {}", config.address)),
        None => logger.info("Connected, but no IPv4 address"),
    }
}

/// The connection and network tasks run in the background.
pub async fn forever(ctx: &'static Context) {
    ctx.delay.delay_ms(1000).await;
}

```
