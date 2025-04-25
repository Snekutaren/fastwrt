# FastWrt Design Philosophy

## Core Principles

FastWrt is built upon four foundational principles that guide all aspects of its development and implementation:

1. **Security by Design**: Security is not an afterthought but the primary consideration in all architectural decisions.
2. **Consistency and Clarity**: Code follows strict patterns that enhance readability and maintainability.
3. **Modularity with Dependencies**: Components are modular but recognize and respect their interdependencies.
4. **Minimal Redundancy**: Code is structured to eliminate duplication while maintaining clear separation of concerns.

## Security Focus

### Multi-layered Approach

FastWrt implements security in layers, following the defense-in-depth principle:

- **Network Segmentation**: Isolated VLANs with explicit rules governing inter-VLAN communication
- **Access Control**: Strict policies for data flow between network zones
- **Authentication**: Key-based authentication prioritized over password-based methods
- **Remote Access**: Limited to secure channels (WireGuard VPN) with no direct WAN exposure
- **Firewall Defaults**: Conservative "deny by default, allow by exception" policy

### Security Principles in Practice

1. **Explicit Over Implicit**: Security permissions are always explicitly declared
2. **Least Privilege**: Each network segment receives only the permissions necessary for its function
3. **Fail Secure**: System defaults to secure state on error conditions
4. **Auditability**: Changes are logged and configurations can be validated

## Code Structure and Standards

### Fish Shell as Standard

FastWrt standardizes on the Fish shell for all scripting, chosen for its:

- Modern syntax with better error prevention
- Improved string handling capabilities
- Clear variable scope delineation
- Enhanced readability and maintainability

Fish shell conventions are enforced throughout the codebase, with strict adherence to:
- Consistent variable declaration syntax
- Standard control structures
- Uniform error handling

### Categorical Organization

The codebase follows a strict organizational structure:

1. **Numeric Prefix Ordering**: Scripts are numbered to enforce execution sequence
2. **Functional Grouping**: Components are grouped by their primary function
3. **Dependency Tracking**: Scripts explicitly declare their dependencies on other components

```
01-*.sh - Initialization and environment setup
10-*.sh - Backup and preparation
20-*.sh - System configuration
30-*.sh - Network infrastructure
40-*.sh - Network services
50-*.sh - Security and access control
60-*.sh - User interfaces
70-*.sh - Remote access
80-*.sh - Validation and verification
```

## Implementation Patterns

### Atomic Changes

FastWrt implements a central commit model where:
1. Individual scripts make UCI configuration changes
2. Changes accumulate in a pending state
3. Validation occurs before application
4. All changes are committed atomically or reverted entirely

This approach prevents partial configurations that could result in an inconsistent or inaccessible state.

### Defensive Programming

All scripts incorporate defensive programming techniques:
- Input validation for all external data
- Existence checks before operations
- Clear error messages with actionable information
- Graceful failure with appropriate exit codes

### Progress Visibility

FastWrt provides clear, color-coded feedback during execution:
- Green: Success messages and completed operations
- Yellow: Warnings and notices
- Red: Errors and critical issues
- Blue: Information messages
- Purple: Section headers and major process indicators
- Orange: Security-related warnings and advisories
- Cyan: Configuration values and technical details

## Development Guidelines

### Code Review Criteria

All contributions to FastWrt are evaluated against these criteria:

1. **Security Impact**: Does the change maintain or improve the security posture?
2. **Consistency**: Does the code follow established patterns and Fish shell best practices?
3. **Modularity**: Is the code properly encapsulated with clear dependencies?
4. **Clarity**: Is the purpose and functionality clearly communicated?

### Commit Discipline

Commits should:
- Address a single logical change
- Include comprehensive documentation updates
- Pass all validation checks
- Maintain backward compatibility or clearly document breaking changes

## Philosophy in Practice

The FastWrt philosophy produces a router configuration that is:

- **Secure by default** without sacrificing usability
- **Structured and predictable** in both code and behavior
- **Maintainable** through consistent patterns and clear documentation
- **Resilient** by anticipating failure modes and providing recovery paths

This foundation ensures that FastWrt remains a reliable, secure, and maintainable solution for network infrastructure deployment.

## Fundamental Design Principles

### Idempotency: The Foundation of Reliability

FastWrt is built on the principle of idempotency - the property that operations can be applied multiple times without changing the result beyond the initial application. This is not merely a technical choice but a fundamental design philosophy:

1. **True Idempotency**: Scripts can be run repeatedly with identical results
   - No accumulation of duplicate entries
   - No unintended side effects from multiple executions
   - Clear cleanup of previous states before applying new configurations

2. **Root Cause Resolution**: Problems are addressed at their source, never through symptom-masking techniques
   - No "fixer scripts" that patch issues without resolving underlying causes
   - No temporary workarounds that become permanent technical debt
   - Configuration issues trigger errors rather than silent corrections

3. **Deterministic Outcomes**: Every script execution produces a predictable, consistent result
   - Initial runs and subsequent runs produce identical configurations
   - Explicit handling of potential conflicts during configuration
   - Verification steps to confirm expected state has been achieved

4. **Clean Slate Approach**: Each functional component fully manages its domain
   - Scripts remove existing configurations before applying new ones
   - Explicit handling of defaults to prevent interference with custom settings
   - Comprehensive validation ensures complete and correct configuration

### Implementation of Idempotency

FastWrt achieves idempotency through several technical approaches:

- **Complete Configuration Management**: Each script fully manages its domain rather than making incremental changes
- **State Verification**: Before creating resources, their current state is verified and adjusted if necessary
- **Conflict Prevention**: Explicit checks for duplicate configurations and resource conflicts
- **Comprehensive Cleanup**: Removing obsolete configurations before applying new ones
- **Validation**: Post-configuration checks to verify the expected state was achieved

This approach eliminates the "configuration drift" that commonly occurs in systems that rely on incremental changes and workarounds.

### Benefits of Idempotent Design

1. **Reliability**: Configurations are predictable and consistent across deployments
2. **Maintainability**: Clean, root-cause focused code is easier to understand and modify
3. **Resilience**: Systems can recover from interrupted operations by simply re-running scripts
4. **Testability**: Deterministic behavior allows for comprehensive testing
5. **Future-proofing**: Addressing root causes prevents the accumulation of technical debt

### Practical Examples

- **Network Configuration**: Complete teardown and rebuild of interfaces instead of incremental adjustments
- **Firewall Rules**: Full replacement of rule sets rather than rule-by-rule modifications
- **DHCP Configuration**: Complete management of DHCP pools rather than adding/modifying individual entries

This idempotent approach ensures that FastWrt configurations remain consistent, predictable, and maintainable throughout their lifecycle.

---

Last Updated: May 1, 2023
