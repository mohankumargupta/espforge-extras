# https_client

This example was generated from these source files.

## `.espf.txt`

```xml
====================
HTTPS CLIENT EXAMPLE

GETs a URL over TLS 1.3 every few seconds with the `<https_client>` service
and logs the response body. `insecure="true"` (dev only) skips certificate
verification, which also makes the build print a warning.
====================

# espforge
  <project name="https_client" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

# peripherals
  <wifi id="radio" />

# components
  <wifi_station id="home" wifi="$radio" ssid="Wokwi-GUEST" auth="open" />

# devices

# services
  <https_client id="secure_client" network="$home" insecure="true" />

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
    let https = service!(ctx, secure_client);
    let mut rx_buf = [0u8; 1024];

    match https
        .get("https://httpbin.org/robots.txt", &mut rx_buf)
        .await
    {
        Ok(body) => {
            if let Ok(text) = core::str::from_utf8(body) {
                ctx.logger
                    .info(format_args!("GET ok, {} bytes: {text}", body.len()));
            }
        }
        Err(err) => ctx.logger.error(format_args!("GET failed: {err:?}")),
    }

    ctx.delay.delay_ms(10000).await;
}

```
