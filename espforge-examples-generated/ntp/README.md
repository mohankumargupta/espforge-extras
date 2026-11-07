# ntp

This example was generated from these source files.

## `.espf.txt`

```xml
====================
NTP CLIENT EXAMPLE

Connects to Wi-Fi, then asks an NTP server for the current time every minute
with the `<ntp>` service. The reply carries Unix seconds, a sub-second
fraction, the round-trip delay and the clock offset relative to the board.
SNTP (RFC 4330) asks clients to poll no more often than once a minute.
====================

# espforge
  <project name="ntp" />
  <chip type="esp32c3" />
  <runtime type="embassy" />

# peripherals
  <wifi id="radio" />

# components
  <wifi_station id="home" wifi="$radio" ssid="Wokwi-GUEST" auth="open" />

# devices

# services
  <ntp id="clock" network="$home" />

```

## `src/app.rs`

```rust
use crate::{component, service, Context};
use embassy_executor::Spawner;

/// Runs once at startup: wait for Wi-Fi, then say what we are about to do.
pub async fn setup(ctx: &'static Context, _spawner: Spawner) {
    ctx.logger.info("Waiting for Wi-Fi connection...");
    component!(ctx, home).wait_connected().await;
    ctx.logger.info("Connected. Starting NTP synchronization.");
}

/// Per-tick loop: one SNTP query, log the time, sleep.
pub async fn forever(ctx: &'static Context) {
    let ntp = service!(ctx, clock);

    match ntp.get_time().await {
        Ok(time) => {
            ctx.logger.info(format_args!(
                "NTP sync: {}.{:06} s since the Unix epoch (RTT {} us, offset {} us)",
                time.unix_seconds, time.microseconds, time.roundtrip_delay_us, time.offset_us
            ));

            // Unix seconds are UTC, so the time of day is a plain division.
            let seconds_in_day = time.unix_seconds % 86400;
            ctx.logger.info(format_args!(
                "Current UTC time: {:02}:{:02}:{:02}",
                seconds_in_day / 3600,
                (seconds_in_day % 3600) / 60,
                seconds_in_day % 60
            ));
        }
        Err(e) => ctx.logger.warn(format_args!("NTP query failed: {e:?}")),
    }

    // SNTP (RFC 4330) asks clients to poll at most once a minute.
    ctx.delay.delay_ms(60000).await;
}

```
