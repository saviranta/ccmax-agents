# Decision 001: Bash(python3 *) and Bash(node *) Permissions

**Date:** 2026-03-22
**Status:** Accepted with mitigation

## Context

The security review identified that `Bash(python3 *)` and `Bash(node *)` in settings.json allow agents to bypass all other sandbox restrictions — an agent can run `python3 -c "open('/path/to/file').read()"` to read files outside the sandbox's deny rules, or make network requests to any domain.

## Decision

**Keep `python3 *` and `node *` allowed.** Removing them would prevent agents from building, testing, and running code — destroying the core value of the Builder agent.

## Mitigation

The macOS sandbox filesystem restrictions are the primary boundary. Within the sandbox, `python3` and `node` can only access files the sandbox allows (project root + agents-max read-only).

Additionally:
- **`security-audit.sh`** scans git history and audit logs for suspicious patterns: hardcoded secrets, curl/wget/nc commands, dynamic code execution, unauthorized file access, binary files, settings tampering
- The **audit log with diffs** captures what agents actually wrote, enabling post-hoc review
- The **validate.sh** script flags if security settings have been weakened
- Agents cannot edit `agents-max/**` scripts (deny rule prevents modifying their own tooling)

## Risk Accepted

If the macOS sandbox has vulnerabilities, an agent could escape. This is an accepted risk because:
1. The sandbox is OS-level enforcement, not LLM-advisory
2. Agents run under the user's subscription (not API), limiting blast radius
3. The security-audit.sh script provides detection capability
4. All agent work is checkpointed in git and can be rolled back

## Review Trigger

Revisit this decision if:
- A macOS sandbox bypass is discovered
- Agents are observed making suspicious network requests
- The security audit flags repeated violations
