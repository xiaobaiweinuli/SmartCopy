use std::path::PathBuf;
use std::sync::OnceLock;
use tracing::{info, error, warn, Level};
use tracing_subscriber::{fmt, prelude::*, EnvFilter};
use tracing_appender::rolling::{RollingFileAppender, Rotation};

static LOG_DIR: OnceLock<PathBuf> = OnceLock::new();

pub fn init_logger() -> Result<(), Box<dyn std::error::Error>> {
    let log_dir = get_log_directory();
    std::fs::create_dir_all(&log_dir)?;

    let file_appender = RollingFileAppender::new(
        Rotation::DAILY,
        &log_dir,
        "smartcopy.log",
    );

    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    let subscriber = tracing_subscriber::registry()
        .with(EnvFilter::from_default_env().add_directive(Level::INFO.into()))
        .with(
            fmt::layer()
                .with_writer(non_blocking)
                .with_ansi(false)
                .with_target(true)
                .with_thread_ids(true)
                .with_file(true)
                .with_line_number(true)
        )
        .with(
            fmt::layer()
                .with_writer(std::io::stdout)
                .with_ansi(true)
                .with_target(false)
        );

    tracing::subscriber::set_global_default(subscriber)?;

    std::mem::forget(_guard);

    info!("SmartCopy 日志系统已初始化");
    info!("日志目录: {:?}", log_dir);

    Ok(())
}

pub fn get_log_directory() -> PathBuf {
    if let Some(dir) = LOG_DIR.get() {
        return dir.clone();
    }

    let exe_path = std::env::current_exe().ok();
    let log_dir = if let Some(exe) = exe_path {
        exe.parent()
            .map(|p| p.join("logs"))
            .unwrap_or_else(get_default_log_dir)
    } else {
        get_default_log_dir()
    };

    LOG_DIR.get_or_init(|| log_dir.clone());
    log_dir
}

fn get_default_log_dir() -> PathBuf {
    dirs::data_local_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("SmartCopy")
        .join("logs")
}

pub fn log_info(prefix: &str, message: &str) {
    info!(target: prefix, "{}", message);
}

pub fn log_error(prefix: &str, message: &str) {
    error!(target: prefix, "{}", message);
}

pub fn log_warn(prefix: &str, message: &str) {
    warn!(target: prefix, "{}", message);
}
