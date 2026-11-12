# Constitution

These principles apply to every spec and every PR. A spec that conflicts with one must say so explicitly and justify it.

1. **On-device first.** Speech is transcribed on the device by default. Audio leaves the device only when the user has saved a
   cloud key and either chose the cloud engine or a local result failed the confidence check.
2. **No secrets in the binary or repository.** API keys are entered by the user and stored in the iOS Keychain. Public App Store
   builds must call cloud providers through a server-side proxy. Commits must never contain keys, `.p8` files or signing material.
3. **Private by default.** History, stats and models stay in the app's sandbox. There is no analytics, tracking or account.
4. **Native platform.** Swift and SwiftUI with Apple frameworks. The keyboard extension stays small: no ML, no large dependencies
   and no JS runtime. That's because extensions have a tight memory limit and can't use the microphone.
5. **Respect iOS rules.** Use only supported APIs and capabilities that pass App Store review: App Groups, background audio while
   recording, and keyboard open access with a clear justification.
6. **Dictation never loses words.** If optimization fails, insert the cleaned transcript. If local inference fails and a fallback
   is available, use the fallback. Errors are shown, not swallowed.
7. **Every behaviour is specified.** Features have IDs, requirements and acceptance criteria in `specs/` before or alongside their
   implementation.
