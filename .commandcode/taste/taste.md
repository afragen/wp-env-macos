# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# Workflow
- For auto-discovering opossum/container `mac-env` wrappers that replace wp-env: include a command to run `env:install` (e.g., `npm run env:install`) to set up a WordPress site instance after provisioning the stack. Confidence: 0.65
- When adding third-party tools that replace system components (e.g., container runtimes), test the add-on/plugin against the existing system first before replacing the system runtime. Confidence: 0.65
- Avoid workflows that require sudo for setup steps (e.g., DNS domain creation, container runtime configuration). Confidence: 0.65
- Bundle dev environment setups (e.g., opossum/container compose stacks with wrappers) as reusable templates that can be ported to other projects. Confidence: 0.60
- Have `init` append the correct npm scripts (env:start, env:stop, test, etc.) to a project's package.json automatically, rather than requiring manual editing. Confidence: 0.70
