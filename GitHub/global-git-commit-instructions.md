# Commit Instructions
Follow the commit message format below.  
Limit the first line to 72 characters or less.

[<change_type>] <commit_message_description>

---

## COMMIT TYPE REFERENCE
| Type       | When to Use                  | Description |
|------------|------------------------------|-------------|
| `[feat]`   | Adding new functionality     | NEW features, capabilities, or user-facing functionality |
| `[fix]`    | Fixing broken code           | REPAIR bugs, errors, or issues |
| `[update]` | Enhancing existing features  | MODIFY or IMPROVE existing functionality (non-breaking) |
| `[break]`  | Breaking changes             | CHANGES that break existing functionality or APIs |
| `[perf]`   | Performance improvements     | OPTIMIZE performance without changing functionality |
| `[refactor]` | Code structure improvements | RESTRUCTURE code with same functionality |
| `[style]`  | Code formatting only         | FORMATTING changes (whitespace, semicolons, etc.) |
| `[test]`   | Test-related changes         | ADD or UPDATE test cases |
| `[docs]`   | Documentation changes        | README files, code comments, markdown docs |
| `[config]` | Configuration changes        | Settings files, environment configs |
| `[deps]`   | Dependency management        | Add/remove/update packages or libraries |
| `[build]`  | Build system changes         | Build scripts, CI/CD, deployment configs |
| `[chore]`  | Maintenance tasks            | Routine cleanup, maintenance, organization |
| `[remove]` | Removing code/features       | DELETE files, features, or deprecated code |
| `[move]`   | File organization            | RELOCATE or RENAME files/folders |

## SELECTION RULES
1. **Choose the PRIMARY change type** — if multiple types apply, pick the most significant  
2. **User-facing changes**: Use `[feat]`, `[fix]`, `[update]`, or `[break]`  
3. **Internal improvements**: Use `[refactor]`, `[perf]`, `[style]`, or `[test]`  
4. **Non-code changes**: Use `[docs]`, `[config]`, `[deps]`, `[build]`, `[chore]`, `[remove]`, or `[move]`

## EXAMPLES
```
[feat] add email notification system to user registration
[fix] resolve null pointer exception in user validation
[update] improve verbose logging in authentication functions
[break] change API response format for user endpoints
[perf] optimize database queries for user lookup
[refactor] extract email logic into separate service class
[style] fix indentation and remove trailing whitespace
[test] add unit tests for user authentication module
[docs] update README with new installation instructions
[config] update database connection settings for production
[deps] upgrade PowerShell module to version 2.1.0
[build] add automated deployment pipeline configuration
[chore] clean up temporary files and unused variables
[remove] delete deprecated user management functions
[move] relocate utility functions to shared library folder
```