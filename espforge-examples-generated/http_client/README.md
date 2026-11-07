# http_client

This example was generated from these source files.

## `.espf.txt`

```xml
====================
HTTP CLIENT EXAMPLE

Connects to Wi-Fi, then GETs http://httpbin.org/robots.txt every few seconds
with the `<http_client>` service and logs the response body. The client is
unencrypted HTTP/1.1 over the station's network stack.
====================

# espforge
  <project name="http_client" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

# peripherals
  <wifi id="radio" />

# components
  <wifi_station id="home" wifi="$radio" ssid="Wokwi-GUEST" auth="open" />

# devices

# services
  <http_client id="client" network="$home" />

```

## `src/app.rs`

```rust
use crate::{component, service, Context};
use embassy_executor::Spawner;

/// Runs once at startup: wait for Wi-Fi, then say what we are about to do.
pub async fn setup(ctx: &'static Context, _spawner: Spawner) {
    ctx.logger.info("Waiting for Wi-Fi connection...");
    component!(ctx, home).wait_connected().await;
    ctx.logger.info("Connected. Ready to make requests.");
}

/// Per-tick loop: one GET, then sleep.
pub async fn forever(ctx: &'static Context) {
    let client = service!(ctx, client);
    let mut rx_buf = [0u8; 1024];

    match client
        .get("http://httpbin.org/robots.txt", &mut rx_buf)
        .await
    {
        Ok(body) => {
            if let Ok(text) = core::str::from_utf8(body) {
                ctx.logger
                    .info(format_args!("GET ok, {} bytes: {text}", body.len()));
            }
        }
        Err(e) => ctx.logger.warn(format_args!("GET failed: {e:?}")),
    }

    ctx.delay.delay_ms(10000).await;
}

```
