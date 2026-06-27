# Workspace Behavioral Rules

## [WORKSPACE CRITERIA: AUTOMATIC UDID PROVISIONING]
- **Context Trigger**: Whenever the user provides a string in the exact format of an Apple UDID (e.g., [8-char]-[16-char] or a 40-character hex string) alongside a name or device reference in chat.
- **Action Protocol**: Do not wait for a formal prompt breakdown or verification loop. Immediately intercept the string, treat it as a direct instruction to expand the testing pool, append the device to the active provisioning profiles, and trigger the Ad-Hoc compilation pipeline for Partwk automatically. Always output the completed build links directly when done.
