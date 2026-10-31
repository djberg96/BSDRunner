use greetd_ipc::{
    codec::SyncCodec, AuthMessageType, Request as GreetdRequest, Response as GreetdResponse,
};
use serde_json::{json, Value};
use std::{
    fs,
    io::{BufRead, BufReader, Write},
    os::unix::net::UnixListener,
    process::{Command, Stdio},
    thread,
};

fn read_event(output: &mut BufReader<std::process::ChildStdout>) -> Value {
    let mut line = String::new();
    output.read_line(&mut line).expect("read bridge event");
    serde_json::from_str(&line).expect("bridge emitted JSON")
}

#[test]
fn completes_secret_authentication_and_starts_the_selected_session() {
    let socket_path = std::env::temp_dir().join(format!(
        "bsdrunner-greetd-test-{}-{}.sock",
        std::process::id(),
        thread::current().name().unwrap_or("protocol")
    ));
    let _ = fs::remove_file(&socket_path);
    let listener = UnixListener::bind(&socket_path).expect("bind fake greetd socket");

    let server = thread::spawn(move || {
        let (mut stream, _) = listener.accept().expect("accept bridge");

        match GreetdRequest::read_from(&mut stream).expect("create session request") {
            GreetdRequest::CreateSession { username } => {
                assert_eq!(username, "\u{1b}dberger");
            }
            request => panic!("unexpected request: {request:?}"),
        }
        GreetdResponse::AuthMessage {
            auth_message_type: AuthMessageType::Secret,
            auth_message: "Password:".to_string(),
        }
        .write_to(&mut stream)
        .expect("write password prompt");

        match GreetdRequest::read_from(&mut stream).expect("password response") {
            GreetdRequest::PostAuthMessageResponse { response } => {
                assert_eq!(response.as_deref(), Some("correct horse battery staple"));
            }
            request => panic!("unexpected request: {request:?}"),
        }
        GreetdResponse::Success
            .write_to(&mut stream)
            .expect("write auth success");

        match GreetdRequest::read_from(&mut stream).expect("start session request") {
            GreetdRequest::StartSession { cmd, env } => {
                assert_eq!(
                    cmd,
                    vec![
                        "/bin/sh",
                        "$HOME/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh",
                        "BSDRunner",
                    ]
                );
                assert_eq!(env, vec!["XDG_SESSION_TYPE=wayland"]);
            }
            request => panic!("unexpected request: {request:?}"),
        }
        GreetdResponse::Success
            .write_to(&mut stream)
            .expect("write session success");
    });

    let mut child = Command::new(env!("CARGO_BIN_EXE_bsdrunner-greetd-greeter"))
        .env("GREETD_SOCK", &socket_path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("start bridge");
    let mut input = child.stdin.take().expect("bridge stdin");
    let mut output = BufReader::new(child.stdout.take().expect("bridge stdout"));

    assert_eq!(read_event(&mut output), json!({ "type": "ready" }));
    writeln!(
        input,
        "{}",
        json!({
            "type": "login",
            "username": "\u{1b}dberger",
            "session": "bsdrunner"
        })
    )
    .expect("send login request");
    assert_eq!(
        read_event(&mut output),
        json!({
            "type": "auth_message",
            "message_type": "secret",
            "message": "Password:"
        })
    );

    writeln!(
        input,
        "{}",
        json!({
            "type": "auth_response",
            "response": "correct horse battery staple"
        })
    )
    .expect("send password");
    assert_eq!(
        read_event(&mut output),
        json!({ "type": "starting_session" })
    );
    assert_eq!(
        read_event(&mut output),
        json!({ "type": "session_started" })
    );

    drop(input);
    assert!(child.wait().expect("wait for bridge").success());
    server.join().expect("fake greetd server");
    fs::remove_file(&socket_path).expect("remove fake greetd socket");
}
