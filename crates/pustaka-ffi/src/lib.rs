uniffi::setup_scaffolding!();

#[uniffi::export]
pub fn init_engine() -> String {
    format!(
        "Pustaka Core Engine initialized (v{}, ACP v{})",
        pustaka_core::version(),
        pustaka_acp::version()
    )
}

#[uniffi::export]
pub fn get_app_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init_engine() {
        let status = init_engine();
        assert!(status.contains("Pustaka Core Engine initialized"));
        assert!(status.contains("v0.1.0"));
    }

    #[test]
    fn test_get_app_version() {
        assert_eq!(get_app_version(), "0.1.0");
    }
}
