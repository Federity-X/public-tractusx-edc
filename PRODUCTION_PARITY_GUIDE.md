# Production Parity Configuration Guide

## Authentication Configuration Issue

The Tractus-X EDC includes both authentication extensions:

1. **Token-based Authentication** (`auth-tokenbased`) - API key authentication
2. **Delegated Authentication** (`auth-delegated`) - JWT-based authentication

### Root Cause Analysis

The issue is that both authentication extensions are loaded, but **delegated authentication has higher priority** and overrides the simple API key authentication. This causes the permissive behavior where requests work without proper authentication headers.

From the logs:

```
[Delegated API Authentication] No audience configured for delegated authentication, defaulting to the participantId
```

This indicates delegated authentication is active but misconfigured, making it permissive.

### Solution Options

#### Option 1: Disable Delegated Authentication (Recommended for Local Development)

Create a custom configuration that excludes delegated authentication:

**Step 1:** Create `dataspaceconnector-secure.properties`

```properties
# Copy all existing settings from dataspaceconnector-configuration.properties
# Plus add these settings to enforce proper API key authentication:

# Disable delegated authentication
web.http.management.auth.type=tokenbased

# Ensure API key is required
web.http.management.auth.key=your-secure-api-key-here

# Optional: Add more security settings
web.http.management.cors.enabled=false
web.http.management.cors.headers=*
```

**Step 2:** Modify the runtime to exclude delegated auth (requires build changes)

#### Option 2: Configure Delegated Authentication Properly (Production-like)

Configure proper JWT authentication with JWKS endpoint:

```properties
# JWT-based authentication configuration
web.http.management.auth.type=delegated

# JWKS endpoint for token validation
edc.oauth.token.url=https://your-oauth-provider/oauth/token
edc.oauth.public.key.alias=your-key-alias
edc.oauth.private.key.alias=your-private-key-alias

# Audience configuration (fixes the permissive behavior)
edc.iam.delegated.auth.audience=your-participant-id

# Token validation settings
edc.iam.delegated.auth.issuer=https://your-oauth-provider
```

#### Option 3: Custom Authentication Extension

Create a development-specific authentication extension that enforces API key authentication without delegated auth interference.

### Immediate Fix for Local Development

To get production-like authentication behavior immediately:

1. **Stop the EDC**

```bash
./stop-dev-env.sh
```

2. **Create a custom configuration**

```bash
cp dataspaceconnector-configuration.properties dataspaceconnector-secure.properties
```

3. **Add these lines to `dataspaceconnector-secure.properties`:**

```properties
# Force token-based authentication
web.http.management.auth.type=tokenbased
web.http.management.auth.key=production-like-secret-key

# Disable permissive delegated auth
edc.iam.delegated.auth.enabled=false
```

4. **Start EDC with secure config**

```bash
java -Dedc.fs.config=dataspaceconnector-secure.properties -jar edc-controlplane/edc-runtime-memory/build/libs/edc-runtime-memory.jar
```

### Verification

Test that authentication is now required:

```bash
# This should fail (401 Unauthorized)
curl -X GET "http://localhost:8181/management/v3/assets" \
  -H "Content-Type: application/json"

# This should succeed
curl -X GET "http://localhost:8181/management/v3/assets" \
  -H "Content-Type: application/json" \
  -H "X-Api-Key: production-like-secret-key"
```

### Build-Level Solution

For a permanent fix, modify the build configuration to exclude delegated authentication in development environments:

**edc-controlplane/edc-controlplane-base/build.gradle.kts:**

```kotlin
configurations.all {
    // Exclude delegated auth for development
    if (project.hasProperty("dev-mode")) {
        exclude(group = "org.eclipse.edc", module = "auth-delegated")
    }
}
```

Then build with: `./gradlew build -Pdev-mode`

### Production Environment Considerations

In production, you should:

1. **Use proper JWT-based authentication** with a real OAuth provider
2. **Configure HTTPS** for all endpoints
3. **Set up proper CORS** policies
4. **Configure secret management** (HashiCorp Vault, etc.)
5. **Enable audit logging** for all API access
6. **Use database persistence** instead of in-memory stores

### Security Best Practices

- Never use simple passwords like "password" in production
- Rotate API keys regularly
- Implement rate limiting
- Use proper TLS certificates
- Monitor authentication failures
- Implement proper access controls based on participant identity

## Summary

The authentication bypass issue is caused by misconfigured delegated authentication that defaults to permissive behavior. The solution is to either properly configure JWT authentication or disable delegated auth and use token-based authentication with proper API keys.
