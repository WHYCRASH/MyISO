// Arkenfox-style user.js for custom Ubuntu 26.04 ISO
// Optimized for security, privacy, and browser sandboxing

// SECTION 01: Startup and UI behavior
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.page", 1); // Start with homepage (blank preferred)
user_pref("browser.startup.homepage", "about:blank");
user_pref("browser.newtabpage.enabled", false); // Blank new tab
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);

// SECTION 02: Telemetry and Data Collection (Complete Opt-Out)
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.server", "data:,");
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("browser.tabs.crashReporting.sendReport", false);

// SECTION 03: Safe Browsing (Privacy Leak Prevention)
// Disable remote lookups that leak URLs to Google
user_pref("browser.safebrowsing.downloads.remote.enabled", false);
user_pref("browser.safebrowsing.downloads.remote.block_dangerous", false);
user_pref("browser.safebrowsing.downloads.remote.block_dangerous_host", false);

// SECTION 04: Location & WebRTC Privacy
user_pref("geo.enabled", false); // Disable Geolocation API
user_pref("geo.provider.use_geoclue", false);
user_pref("media.peerconnection.enabled", false); // Disable WebRTC to prevent local IP leaks
user_pref("media.peerconnection.use_document_iceservers", false);
user_pref("media.navigator.enabled", false); // Block camera/mic device enumeration

// SECTION 05: Tracking Protection and Privacy
user_pref("privacy.trackingprotection.enabled", true);
user_pref("privacy.trackingprotection.socialtracking.enabled", true);
user_pref("privacy.trackingprotection.fingerprinting.enabled", true);
user_pref("privacy.trackingprotection.cryptomining.enabled", true);
user_pref("privacy.trackingprotection.pbmode.enabled", true);
user_pref("privacy.firstparty.isolate", true); // Enable First Party Isolation
user_pref("network.cookie.cookieBehavior", 4); // Reject cross-site cookies

// SECTION 06: Resist Fingerprinting (RFP)
user_pref("privacy.resistFingerprinting", true);
user_pref("privacy.resistFingerprinting.letterboxing", true); // Mitigates viewport sizing fingerprinting
user_pref("webgl.disabled", true); // Disable WebGL (major fingerprinting vector)

// SECTION 07: Security & Encryption
user_pref("dom.security.https_only_mode", true); // Force HTTPS everywhere
user_pref("dom.security.https_only_mode_ever_enabled", true);
user_pref("security.ssl.require_safe_negotiation", true);
user_pref("security.tls.version.min", 3); // Limit to TLS 1.2 and 1.3
user_pref("network.http.referer.XOriginPolicy", 2); // Send referrers only if protocol and host match
user_pref("network.http.referer.XOriginTrimmingPolicy", 2); // Send only host portion in referrer

// SECTION 08: Cache, Cookies & Session Cleanliness
user_pref("browser.sessionstore.privacy_level", 2); // Never save passwords/data for encrypted sites
user_pref("privacy.sanitize.sanitizeOnShutdown", true); // Clean history on exit
user_pref("privacy.clearOnShutdown.cache", true);
user_pref("privacy.clearOnShutdown.cookies", true);
user_pref("privacy.clearOnShutdown.downloads", true);
user_pref("privacy.clearOnShutdown.formdata", true);
user_pref("privacy.clearOnShutdown.history", true);
user_pref("privacy.clearOnShutdown.sessions", true);

// SECTION 09: Feature Disabling (Bloatware)
user_pref("extensions.pocket.enabled", false); // Disable Pocket
user_pref("identity.fxaccounts.enabled", false); // Disable Firefox Sync Accounts
user_pref("reader.parse-on-load.enabled", false); // Disable reader mode
user_pref("browser.shopping.experience2023.enabled", false); // Disable shopping telemetry
