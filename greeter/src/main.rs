use greetd_ipc::{
    codec::SyncCodec, AuthMessageType, ErrorType, Request as GreetdRequest,
    Response as GreetdResponse,
};
use serde::{Deserialize, Serialize};
use std::{
    env,
    error::Error,
    io::{self, BufRead, Write},
    os::unix::net::UnixStream,
};

type Result<T> = std::result::Result<T, Box<dyn Error>>;

#[derive(Debug, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum UiRequest {
    Login { username: String, session: Session },
    AuthResponse { response: Option<String> },
    Cancel,
}

#[derive(Clone, Copy, Debug, Deserialize)]
#[serde(rename_all = "snake_case")]
enum Session {
    Bsdrunner,
    Terminal,
}

impl Session {
    fn command(self) -> Vec<String> {
        let name = match self {
            Self::Bsdrunner => "BSDRunner",
            Self::Terminal => "Terminal",
        };

        vec![
            "/bin/sh".to_string(),
            "$HOME/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh".to_string(),
            name.to_string(),
        ]
    }
}

#[derive(Debug, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum UiEvent<'a> {
    Ready,
    AuthMessage {
        message_type: UiMessageType,
        message: &'a str,
    },
    Notice {
        level: UiNoticeLevel,
        message: &'a str,
    },
    StartingSession,
    SessionStarted,
    Canceled,
    Error {
        kind: UiErrorKind,
        message: &'a str,
    },
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum UiMessageType {
    Visible,
    Secret,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum UiNoticeLevel {
    Info,
    Error,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
enum UiErrorKind {
    Authentication,
    Backend,
    Input,
}

struct Login {
    stream: UnixStream,
    session: Session,
}

enum State {
    Idle,
    WaitingForAuth(Login),
}

fn emit(event: UiEvent<'_>) -> Result<()> {
    let stdout = io::stdout();
    let mut output = stdout.lock();
    serde_json::to_writer(&mut output, &event)?;
    output.write_all(b"\n")?;
    output.flush()?;
    Ok(())
}

fn send(stream: &mut UnixStream, request: GreetdRequest) -> Result<GreetdResponse> {
    request.write_to(stream)?;
    Ok(GreetdResponse::read_from(stream)?)
}

fn cancel(login: &mut Login) {
    let _ = GreetdRequest::CancelSession.write_to(&mut login.stream);
}

fn handle_response(mut login: Login, mut response: GreetdResponse) -> Result<State> {
    loop {
        match response {
            GreetdResponse::AuthMessage {
                auth_message_type,
                ref auth_message,
            } => match auth_message_type {
                AuthMessageType::Visible => {
                    emit(UiEvent::AuthMessage {
                        message_type: UiMessageType::Visible,
                        message: auth_message,
                    })?;
                    return Ok(State::WaitingForAuth(login));
                }
                AuthMessageType::Secret => {
                    emit(UiEvent::AuthMessage {
                        message_type: UiMessageType::Secret,
                        message: auth_message,
                    })?;
                    return Ok(State::WaitingForAuth(login));
                }
                AuthMessageType::Info => {
                    emit(UiEvent::Notice {
                        level: UiNoticeLevel::Info,
                        message: auth_message,
                    })?;
                    response = send(
                        &mut login.stream,
                        GreetdRequest::PostAuthMessageResponse { response: None },
                    )?;
                }
                AuthMessageType::Error => {
                    emit(UiEvent::Notice {
                        level: UiNoticeLevel::Error,
                        message: auth_message,
                    })?;
                    response = send(
                        &mut login.stream,
                        GreetdRequest::PostAuthMessageResponse { response: None },
                    )?;
                }
            },
            GreetdResponse::Success => {
                emit(UiEvent::StartingSession)?;
                response = send(
                    &mut login.stream,
                    GreetdRequest::StartSession {
                        cmd: login.session.command(),
                        env: vec!["XDG_SESSION_TYPE=wayland".to_string()],
                    },
                )?;

                match response {
                    GreetdResponse::Success => {
                        emit(UiEvent::SessionStarted)?;
                        return Ok(State::Idle);
                    }
                    GreetdResponse::Error {
                        ref description, ..
                    } => {
                        emit(UiEvent::Error {
                            kind: UiErrorKind::Backend,
                            message: description,
                        })?;
                        cancel(&mut login);
                        return Ok(State::Idle);
                    }
                    GreetdResponse::AuthMessage { .. } => {
                        emit(UiEvent::Error {
                            kind: UiErrorKind::Backend,
                            message: "greetd requested more authentication after session start",
                        })?;
                        cancel(&mut login);
                        return Ok(State::Idle);
                    }
                }
            }
            GreetdResponse::Error {
                error_type,
                ref description,
            } => {
                let kind = match error_type {
                    ErrorType::AuthError => UiErrorKind::Authentication,
                    ErrorType::Error => UiErrorKind::Backend,
                };
                emit(UiEvent::Error {
                    kind,
                    message: description,
                })?;
                cancel(&mut login);
                return Ok(State::Idle);
            }
        }
    }
}

fn process(request: UiRequest, state: State, socket_path: &str) -> Result<State> {
    match (request, state) {
        (UiRequest::Login { username, session }, State::Idle) => {
            if username.trim().is_empty() {
                emit(UiEvent::Error {
                    kind: UiErrorKind::Input,
                    message: "a username is required",
                })?;
                return Ok(State::Idle);
            }

            let mut login = Login {
                stream: UnixStream::connect(socket_path)?,
                session,
            };
            let response = send(
                &mut login.stream,
                GreetdRequest::CreateSession {
                    username: username.trim().to_string(),
                },
            )?;
            handle_response(login, response)
        }
        (UiRequest::AuthResponse { response }, State::WaitingForAuth(mut login)) => {
            let greetd_response = send(
                &mut login.stream,
                GreetdRequest::PostAuthMessageResponse { response },
            )?;
            handle_response(login, greetd_response)
        }
        (UiRequest::Cancel, State::WaitingForAuth(mut login)) => {
            cancel(&mut login);
            emit(UiEvent::Canceled)?;
            Ok(State::Idle)
        }
        (UiRequest::Cancel, State::Idle) => {
            emit(UiEvent::Canceled)?;
            Ok(State::Idle)
        }
        (UiRequest::Login { .. }, state @ State::WaitingForAuth(_)) => {
            emit(UiEvent::Error {
                kind: UiErrorKind::Input,
                message: "an authentication request is already active",
            })?;
            Ok(state)
        }
        (UiRequest::AuthResponse { .. }, State::Idle) => {
            emit(UiEvent::Error {
                kind: UiErrorKind::Input,
                message: "greetd is not waiting for an authentication response",
            })?;
            Ok(State::Idle)
        }
    }
}

fn run() -> Result<()> {
    let socket_path = env::var("GREETD_SOCK")?;
    let stdin = io::stdin();
    let mut state = State::Idle;

    emit(UiEvent::Ready)?;

    for line in stdin.lock().lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }

        match serde_json::from_str::<UiRequest>(&line) {
            Ok(request) => {
                state = match process(request, state, &socket_path) {
                    Ok(next_state) => next_state,
                    Err(error) => {
                        let message = error.to_string();
                        emit(UiEvent::Error {
                            kind: UiErrorKind::Backend,
                            message: &message,
                        })?;
                        State::Idle
                    }
                }
            }
            Err(error) => emit(UiEvent::Error {
                kind: UiErrorKind::Input,
                message: &format!("invalid UI request: {error}"),
            })?,
        }
    }

    if let State::WaitingForAuth(mut login) = state {
        cancel(&mut login);
    }
    Ok(())
}

fn main() {
    if let Err(error) = run() {
        let message = error.to_string();
        let _ = emit(UiEvent::Error {
            kind: UiErrorKind::Backend,
            message: &message,
        });
        std::process::exit(1);
    }
}
