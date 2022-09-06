//
// Copyright (c) 2022 ZettaScale Technology
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0, or the Apache License, Version 2.0
// which is available at https://www.apache.org/licenses/LICENSE-2.0.
//
// SPDX-License-Identifier: EPL-2.0 OR Apache-2.0
//
// Contributors:
//   ZettaScale Zenoh Team, <zenoh@zettascale.tech>
//
use clap::{App, Arg};
use std::time::{Duration, SystemTime};
use zenoh::config::Config;
use zenoh::prelude::*;
use zenoh::publication::CongestionControl;

fn main() {
    // initiate logging
    env_logger::init();
    let (config, size, ke, rate) = parse_args();

    let data: Value = (0usize..size)
        .map(|i| (i % 10) as u8)
        .collect::<Vec<u8>>()
        .into();

    let session = zenoh::open(config).wait().unwrap();

    let key_expr = session.declare_expr(&ke).wait().unwrap();

    let sleep_time = 1.0 / rate as f64;

    let mut last = 0.00;
    loop {
        std::thread::sleep(Duration::from_secs_f64(sleep_time));
        let now = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs_f64();

        session
            .put(&key_expr, data.clone())
            // Make sure to not drop messages because of congestion control
            .congestion_control(CongestionControl::Drop)
            // Set the right priority
            .wait()
            .unwrap();

        let elapsed = now - last;

        let fps = 1.00 / elapsed;

        println!("[TS: {now} - FPS(real): {fps} - FPS(configured): {rate}  - Elapsed: {elapsed}");

        last = now;
    }
}

fn parse_args() -> (Config, usize, String, usize) {
    let args = App::new("zenoh throughput pub example")
        .arg(
            Arg::from_usage("-m, --mode=[MODE] 'The zenoh session mode (peer by default).")
                .possible_values(&["peer", "client"]),
        )
        .arg(
            Arg::from_usage("-k, --key=[KEYEXPR]        'The key expression to publish onto.'")
                .default_value("/demo/example/zenoh-rs-pub"),
        )
        .arg(
            Arg::from_usage("-r, --rate=[RATE]        'Number of message/second to send'")
                .default_value("15"),
        )
        .arg(Arg::from_usage(
            "-e, --connect=[ENDPOINT]...  'Endpoints to connect to.'",
        ))
        .arg(Arg::from_usage(
            "-l, --listen=[ENDPOINT]...   'Endpoints to listen on.'",
        ))
        .arg(Arg::from_usage(
            "-c, --config=[FILE]      'A configuration file.'",
        ))
        .arg(Arg::from_usage(
            "--no-multicast-scouting 'Disable the multicast-based scouting mechanism.'",
        ))
        .arg(Arg::from_usage(
            "<PAYLOAD_SIZE>          'Sets the size of the payload to publish'",
        ))
        .get_matches();

    let mut config = if let Some(conf_file) = args.value_of("config") {
        Config::from_file(conf_file).unwrap()
    } else {
        Config::default()
    };

    if let Some(Ok(mode)) = args.value_of("mode").map(|mode| mode.parse()) {
        config.set_mode(Some(mode)).unwrap();
    }
    if let Some(values) = args.values_of("connect") {
        config
            .connect
            .endpoints
            .extend(values.map(|v| v.parse().unwrap()))
    }
    if let Some(values) = args.values_of("listen") {
        config
            .listen
            .endpoints
            .extend(values.map(|v| v.parse().unwrap()))
    }
    if args.is_present("no-multicast-scouting") {
        config.scouting.multicast.set_enabled(Some(false)).unwrap();
    }

    let size = args
        .value_of("PAYLOAD_SIZE")
        .unwrap()
        .parse::<usize>()
        .unwrap();
    let rate = args.value_of("rate").unwrap().parse::<usize>().unwrap();
    let key_expr = args.value_of("key").unwrap().to_string();
    (config, size, key_expr, rate)
}
