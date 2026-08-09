# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# Workflow
See [workflow/taste.md](workflow/taste.md)
# Communication
- Approves plans tersely (e.g., "make changes") and expects immediate execution of the outlined plan rather than further discussion or confirmation. Confidence: 0.5
- Reports bugs and debugging follow-ups tersely, supplying only the key narrowing fact (e.g., "it does work for latest") and expecting the agent to investigate to root cause, fix, and verify rather than asking clarifying questions. Confidence: 0.6

# Documentation
- Prefers documentation to present a single default workflow rather than multiple variants/options; when one variant is made the default, the superseded variant's instructions should be removed entirely, not kept alongside. Confidence: 0.85
- Prefers docs to keep a replaced tool's positioning only as "drop-in replacement" / "no dependency" statements, while stripping all install-and-run instructions for it. Confidence: 0.65
- When renaming a command/tool name across documentation, prefers a complete rename of every reference — including section headings and their internal anchor links — so cross-references stay valid; verify afterward that only intentional mentions remain. Confidence: 0.7
- When a package ships both a primary command name and a working alias (both bins installed), prefers docs to default every command, heading, and piece of prose to the primary name while keeping a single accurate alias note (e.g., "`wp-env-macos` (alias `mac-env`)") rather than purging the alias mention entirely. Confidence: 0.7
