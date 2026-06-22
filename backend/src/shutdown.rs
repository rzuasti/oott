use std::future::Future;

use log::info;
use tokio_util::sync::CancellationToken;

/// Wait for a process-termination signal, then cancel `token` so every long-running task can wind
/// down gracefully instead of being hard-killed.
///
/// We listen for both signals an orchestrator might send:
/// - **SIGTERM** — what Kubernetes and `docker stop` send first, before falling back to SIGKILL
///   once the grace period expires. Catching it lets us exit cleanly within that window.
/// - **SIGINT** — Ctrl-C in an interactive terminal (and `docker run -it`).
pub async fn watch_for_signals(token: CancellationToken) {
    cancel_after(await_termination_signal(), token).await;
}

/// Resolve when the first termination signal arrives.
async fn await_termination_signal() {
    tokio::select! {
        _ = sigint() => info!("Received SIGINT (Ctrl-C); starting graceful shutdown"),
        _ = sigterm() => info!("Received SIGTERM; starting graceful shutdown"),
    }
}

/// Await `signal`, then cancel `token`. Split out from [`watch_for_signals`] so the
/// "cancel once the trigger resolves" contract can be tested without raising a real signal.
async fn cancel_after<F: Future<Output = ()>>(signal: F, token: CancellationToken) {
    signal.await;
    token.cancel();
}

async fn sigint() {
    // If Ctrl-C cannot be hooked, never resolve so the SIGTERM arm of the select still governs.
    if tokio::signal::ctrl_c().await.is_err() {
        std::future::pending::<()>().await;
    }
}

#[cfg(unix)]
async fn sigterm() {
    use tokio::signal::unix::{SignalKind, signal};
    match signal(SignalKind::terminate()) {
        Ok(mut stream) => {
            stream.recv().await;
        }
        // Without a working handler, never resolve so the SIGINT arm still governs.
        Err(_) => std::future::pending::<()>().await,
    }
}

#[cfg(not(unix))]
async fn sigterm() {
    // SIGTERM is a Unix concept; on other platforms only Ctrl-C triggers shutdown.
    std::future::pending::<()>().await;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn cancels_the_token_once_the_signal_resolves() {
        let token = CancellationToken::new();
        assert!(!token.is_cancelled());

        // A signal that resolves immediately stands in for a real SIGTERM/SIGINT.
        cancel_after(std::future::ready(()), token.clone()).await;

        assert!(token.is_cancelled());
    }

    #[tokio::test]
    async fn does_not_cancel_before_the_signal_resolves() {
        let token = CancellationToken::new();

        // A signal that never resolves must leave the token untouched.
        tokio::select! {
            _ = cancel_after(std::future::pending::<()>(), token.clone()) => {
                panic!("cancel_after returned before the signal resolved")
            }
            _ = tokio::time::sleep(std::time::Duration::from_millis(20)) => {}
        }

        assert!(!token.is_cancelled());
    }
}
