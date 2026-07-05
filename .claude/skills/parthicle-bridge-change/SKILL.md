---
name: parthicle-bridge-change
description: Plan, implement, or review Parthicle Reader Java, JNI/C++, QML, Android URI, and TextToSpeech bridge changes. Use when a feature crosses mobile/app, mobile/android/src, or mobile/components.
---

# Change the Android bridge

Map the existing call path before editing. Preserve Okular's `DocumentItem`/`URIHandler` flow and make the smallest end-to-end change.

For each operation, write a contract row with:

- QML caller, arguments, expected state/error;
- C++ `Q_INVOKABLE`, return type, and JNI call;
- Java class, method, `static` status, argument/return types;
- JNI descriptor such as `(Ljava/lang/String;)Z`;
- activity/thread/lifecycle requirements.

Update all contract layers together. Verify class names use JNI slash notation, Java primitives match C++ JNI types, string/object ownership is safe, null activity has a defined result, and callbacks reaching Qt cross threads deliberately.

For Android TextToSpeech:

1. Initialize and call the engine on the main looper.
2. Ignore stale callbacks after engine replacement by using a generation/token.
3. Use unique utterance IDs and deterministic chunk ordering.
4. Define stop, restart, error, unavailable, ready, and speaking transitions.
5. Stop/shutdown on lifecycle teardown and do not retain a dead Activity.
6. Surface engine, voice, language, and synthesis errors without inventing success.

Run `scripts/verify-bridge.ps1`, then compile the affected Java/C++/QML targets. Require an emulator/device test for runtime claims. If Semgrep is installed, optionally scan the bridge directories; its absence is not a failure.
