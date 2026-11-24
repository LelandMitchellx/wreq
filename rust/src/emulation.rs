use wreq_util::Profile;

pub fn resolve_emulation(name: Option<&str>) -> Profile {
    match name {
        Some("chrome149") | Some("chrome") | Some("chrome_149") => Profile::Chrome149,
        Some("safariIos26_2") | Some("safari_ios") | Some("safari_ios_26.2") | Some("safari") => {
            Profile::SafariIos26_2
        }
        Some("firefox151") | Some("firefox") | Some("firefox_151") => Profile::Firefox151,
        // 历史与别名兼容
        Some("chrome131") => Profile::Chrome149,
        Some("firefox133") => Profile::Firefox151,
        Some("safari26") | Some("safari26_4") => Profile::SafariIos26_2,
        _ => Profile::SafariIos26_2,
    }
}
