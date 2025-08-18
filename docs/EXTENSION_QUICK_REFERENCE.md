# Extension Development Quick Reference

**✅ PRODUCTION-READY GUIDE**: Updated with live data masking transformer patterns and validated production examples.

## 🚀 Quick Start

### Development Extension (Basic)

```bash
# 1. Create a new extension using the helper script
./create-extension.sh my-custom-extension

# 2. Build and test
./gradlew :edc-extensions:my-custom-extension:build

# 3. Include in memory runtime (development only)
# Add to edc-runtime-memory/build.gradle.kts:
# implementation(project(":edc-extensions:my-custom-extension"))
```

### Production Extension (Tractus-X Compatible) ⭐ **RECOMMENDED**

```bash
# 1. Create extension structure
./create-extension.sh my-custom-extension

# 2. Set up infrastructure
docker run --name edc-postgres -e POSTGRES_DB=edc -e POSTGRES_USER=edc -e POSTGRES_PASSWORD=password -p 5433:5432 -d postgres:13
docker run --name edc-vault --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=root' -p 8200:8200 -d vault:latest

# 3. Add to production runtime
# Edit edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build.gradle.kts:
# runtimeOnly(project(":edc-extensions:my-custom-extension"))

# 4. Build and run with full stack
./gradlew :edc-controlplane:edc-controlplane-postgresql-hashicorp-vault:shadowJar
java -Dedc.fs.config=tractus-x-config.properties -jar edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build/libs/edc-controlplane-postgresql-hashicorp-vault.jar

# 5. Test with live APIs (verify 160+ extensions loaded)
curl -X GET http://localhost:8181/management -H "X-Api-Key: password"

# 6. Test extension functionality (example: data masking)
curl -X POST "http://localhost:8181/management/v3/assets" -H "X-Api-Key: password" -H "Content-Type: application/json" -d '{"@id": "test-asset", "properties": {"businessPartnerNumber": "BPN123456789"}}'
curl -X GET "http://localhost:8181/management/v3/assets/test-asset" -H "X-Api-Key: password" | jq
```

## 📁 Extension Structure

```
edc-extensions/my-extension/
├── build.gradle.kts                     # Dependencies and build config
├── README.md                            # Extension documentation
└── src/
    ├── main/
    │   ├── java/org/eclipse/tractusx/edc/extensions/myext/
    │   │   ├── MyExtension.java          # Main extension class
    │   │   ├── MyService.java            # Service interface
    │   │   ├── MyServiceImpl.java        # Service implementation
    │   │   └── MyTransformer.java        # ⭐ NEW: Transformer for API processing
    │   └── resources/META-INF/services/
    │       └── org.eclipse.edc.spi.system.ServiceExtension
    └── test/java/org/eclipse/tractusx/edc/extensions/myext/
        └── MyExtensionTest.java          # Extension tests
```

## 🔧 Key Annotations

```java
@Extension(value = "My Extension")                    // Marks the main extension class
@Extension(value = "My Extension", categories = {"policy"}) // With categories
@Inject                                               // Inject dependencies
@Provider                                             // Provide services to other extensions
@Provider(isDefault = true)                           // Provide default implementation
@Setting(value = "Description", key = "edc.my.setting", required = false) // Configuration settings
```

## 📝 Extension Template

### Basic Extension

```java
@Extension(value = "My Extension")
public class MyExtension implements ServiceExtension {

    @Setting(value = "My setting", key = "edc.my.setting", required = false)
    public static final String MY_SETTING = "edc.my.setting";

    @Inject
    private Monitor monitor;

    @Override
    public String name() {
        return "My Extension";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var setting = context.getSetting(MY_SETTING, "default-value");
        monitor.info("Initializing with setting: " + setting);
        // Initialize your extension
    }

    @Provider
    public MyService createMyService(ServiceExtensionContext context) {
        return new MyServiceImpl(monitor);
    }
}
```

### Advanced Extension with Transformer Integration ⭐ **PRODUCTION PATTERN**

```java
@Extension(value = "My Extension with API Processing")
public class MyExtension implements ServiceExtension {

    @Inject
    private Monitor monitor;

    @Inject
    private JsonBuilderFactory jsonBuilderFactory;

    @Override
    public void initialize(ServiceExtensionContext context) {
        // Register transformer for API response processing
        var managementApiTransformerRegistry = context.getService(TypeTransformerRegistry.class, "management-api");
        var myService = createMyService(context);
        managementApiTransformerRegistry.register(new MyTransformer(myService, jsonBuilderFactory));

        monitor.info("My Extension initialized with transformer integration");
    }

    @Provider
    public MyService createMyService(ServiceExtensionContext context) {
        return new MyServiceImpl(monitor);
    }
}
```

### Transformer Implementation Example

```java
public class MyTransformer implements TypeTransformer<Asset, JsonObject> {

    private final MyService myService;
    private final JsonBuilderFactory jsonBuilderFactory;

    @Override
    public Class<Asset> getInputType() { return Asset.class; }

    @Override
    public Class<JsonObject> getOutputType() { return JsonObject.class; }

    @Override
    public JsonObject transform(Asset asset, TransformerContext context) {
        // ⚠️ CRITICAL: Use EDC_NAMESPACE for JSON-LD compliance
        var processedProperties = myService.processProperties(asset.getProperties());

        return jsonBuilderFactory.createObjectBuilder()
            .add(ID, asset.getId())
            .add(EDC_NAMESPACE + "properties", processedProperties)  // EDC namespace compliance
            .add(EDC_NAMESPACE + "dataAddress", processDataAddress(asset.getDataAddress()))
            .build();
    }
}
```

## 🔗 Common Dependencies

```kotlin
// Core EDC
implementation(project(":spi:core-spi"))
implementation(project(":core:core-utils"))

// Common EDC SPIs
implementation(libs.edc.spi.catalog)
implementation(libs.edc.spi.contract)
implementation(libs.edc.spi.policyengine)

// JSON processing
implementation(libs.jakartaJson)

// Testing
testImplementation(libs.edc.junit)
testImplementation(libs.mockito.core)
testImplementation(libs.assertj.core)

// BOMs for runtime modules
runtimeOnly(libs.edc.bom.controlplane.base)
runtimeOnly(libs.edc.bom.controlplane.dcp)
```

## 🧪 Testing Pattern

```java
@ExtendWith(DependencyInjectionExtension.class)
class MyExtensionTest {

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        // Register mock services if needed
        // context.registerService(SomeService.class, mock(SomeService.class));
    }

    @Test
    void shouldInitializeExtension(MyExtension extension, ServiceExtensionContext context) {
        extension.initialize(context);
        assertThat(extension.name()).isEqualTo("My Extension");
    }

    @Test
    void shouldProvideService(MyExtension extension, ServiceExtensionContext context) {
        var service = extension.createMyService(context);
        assertThat(service).isNotNull();
    }
}
```

## ⚙️ Configuration

### Basic Configuration

```java
// In extension class - with key attribute
@Setting(value = "Description", key = "edc.my.setting", required = false, defaultValue = "default")
public static final String SETTING_KEY = "edc.my.setting";

// Complex configuration example
@Setting(value = "Endpoint URL", key = "edc.my.endpoint", required = false)
private String endpointUrl;

// In initialize method
var value = context.getSetting(SETTING_KEY, "fallback-default");
```

### Production Configuration (Tractus-X)

```properties
# Core EDC Configuration
edc.participant.id=BPNL000000000001
edc.api.auth.key=password

# Database Configuration (PostgreSQL)
edc.datasource.edc.url=jdbc:postgresql://localhost:5433/edc
edc.datasource.edc.user=edc
edc.datasource.edc.password=password

# Vault Configuration
edc.vault.hashicorp.url=http://localhost:8200
edc.vault.hashicorp.token=root

# API Endpoints
web.http.management.port=8181
web.http.management.path=/management
web.http.protocol.port=8282
web.http.protocol.path=/protocol

# Tractus-X Specific
tx.sts.oauth.token.url=https://sts.example.com/token
tx.bdrs.server.url=https://bdrs.example.com

# Your Extension Configuration
edc.my.setting=production-value
edc.my.processing.enabled=true
edc.my.strategy=ADVANCED
```

## 📚 Service Registration

```java
// In META-INF/services/org.eclipse.edc.spi.system.ServiceExtension
org.eclipse.tractusx.edc.extensions.myext.MyExtension
```

## 🔍 Common Patterns

### HTTP API Controller

```java
@Provider
public MyApiController createApiController(ServiceExtensionContext context) {
    return new MyApiController(webService, monitor);
}
```

### Policy Function Registration

```java
@Override
public void initialize(ServiceExtensionContext context) {
    policyEngine.registerFunction(CatalogPolicyContext.class, Permission.class,
                                 "myConstraint", new MyPolicyFunction<>());
    ruleBindingRegistry.bind("myConstraint", "catalog");
}
```

### Default Service Provider

```java
@Provider(isDefault = true)
public MyService createDefaultService() {
    return new InMemoryMyService();
}
```

### Transform Registry

```java
@Override
public void initialize(ServiceExtensionContext context) {
    transformerRegistry.register(new MyTransformer());
}
```

### TypeTransformerRegistry Integration ⭐ **NEW PATTERN**

```java
@Override
public void initialize(ServiceExtensionContext context) {
    // Register transformer for management API context
    var managementApiTransformerRegistry = context.getService(TypeTransformerRegistry.class, "management-api");
    managementApiTransformerRegistry.register(new JsonObjectAssetTransformer(myService, jsonBuilderFactory));

    monitor.info("Transformer registered for API response processing");
}
```

### Live API Processing Example ✅ **PRODUCTION VALIDATED**

```java
// Example: Data masking transformer for Asset objects
public class JsonObjectAssetMaskingTransformer implements TypeTransformer<Asset, JsonObject> {

    @Override
    public JsonObject transform(Asset asset, TransformerContext context) {
        // Process and mask sensitive data
        JsonObject maskedProperties = maskSensitiveData(asset.getProperties());

        // ⚠️ CRITICAL: Use EDC_NAMESPACE for proper JSON-LD processing
        return Json.createObjectBuilder()
            .add(ID, asset.getId())
            .add(EDC_NAMESPACE + "properties", maskedProperties)
            .add(EDC_NAMESPACE + "dataAddress", processDataAddress(asset.getDataAddress()))
            .build();
    }
}

// Result: Live API responses show processed data
// Before: {"businessPartnerNumber": "BPN123456789"}
// After:  {"businessPartnerNumber": "B***9"}
```

## 🐛 Debugging Tips

### Extension Loading Issues

1. **Check META-INF service registration**: Verify file path and content
2. **Verify settings.gradle.kts**: Ensure module is included
3. **Check runtime dependencies**: Confirm extension added to target runtime
4. **Look for initialization logs**: Search for extension name in startup output

### Configuration Problems

5. **Missing Tractus-X URLs**: Add STS, BDRS, MIW endpoints for production
6. **Database connection**: Verify PostgreSQL running on port 5433
7. **Vault access**: Confirm token and secret paths are correct

### Runtime Testing

8. **Test with production runtime**: Use `edc-controlplane-postgresql-hashicorp-vault`
9. **Verify 160+ extensions load**: Check total extension count in logs
10. **Test live APIs**: Use `curl` commands against management API (port 8181)
11. **Check extension functionality**: Test actual extension features, not just loading

### Common Commands

```bash
# Check if extension loads
grep "My Extension" logs/runtime.log

# Test management API
curl -X GET http://localhost:8181/management -H "X-Api-Key: password"

# Check database connection
docker logs edc-postgres

# Check vault status
curl -X GET http://localhost:8200/v1/sys/health
```

## 🚀 Runtime Integration

### Development Runtime (Limited)

```kotlin
// For edc-runtime-memory (basic development only)
dependencies {
    implementation(project(":edc-extensions:my-extension"))
}
```

### Production Runtime (Recommended for Tractus-X)

```kotlin
// For edc-controlplane-postgresql-hashicorp-vault
dependencies {
    // ... existing dependencies
    runtimeOnly(project(":edc-extensions:my-extension"))
}

// With exclusions if needed
configurations.all {
    exclude(group = "org.eclipse.edc", module = "conflicting-module")
}
```

### Base Runtime Integration

```kotlin
// Many extensions auto-included via base runtimes
// Check these files:
// - edc-controlplane-base/build.gradle.kts
// - edc-dataplane-base/build.gradle.kts

dependencies {
    runtimeOnly(libs.edc.bom.controlplane.base)
    runtimeOnly(libs.edc.bom.controlplane.dcp)
    implementation(project(":edc-extensions:my-extension"))
}
```

### Runtime Comparison

| Runtime                                     | Use Case    | Extensions | Infrastructure   | API Testing |
| ------------------------------------------- | ----------- | ---------- | ---------------- | ----------- |
| edc-runtime-memory                          | Development | ~50        | None             | Limited     |
| edc-controlplane-postgresql-hashicorp-vault | Production  | 160+       | PostgreSQL+Vault | Full        |

## ✅ Production Validation Checklist

### Infrastructure Check

```bash
# PostgreSQL running
docker ps | grep edc-postgres

# Vault running
docker ps | grep edc-vault

# Vault health check
curl -X GET http://localhost:8200/v1/sys/health
```

### Extension Loading Verification

```bash
# Check extension in startup logs
grep "My Extension initialized" runtime.log

# Verify extension count (should be 160+ for full Tractus-X)
grep "service extensions" runtime.log

# No errors during startup
grep "ERROR\|WARN" runtime.log | grep -i "my-extension"

# ⭐ NEW: Verify transformer registration
grep "Transformer registered" runtime.log
grep "TypeTransformerRegistry" runtime.log
```

### API Testing with Live Data Processing

```bash
# Management API responds
curl -X GET http://localhost:8181/management -H "X-Api-Key: password"

# Create test data with extension processing
curl -X POST "http://localhost:8181/management/v3/assets" \
  -H "X-Api-Key: password" -H "Content-Type: application/json" \
  -d '{"@id": "test-asset", "properties": {"businessPartnerNumber": "BPN123456789", "email": "test@example.com"}}'

# Verify processed response (example: data masking)
curl -X GET "http://localhost:8181/management/v3/assets/test-asset" \
  -H "X-Api-Key: password" | jq '.["https://w3id.org/edc/v0.0.1/ns/properties"]'

# Expected result (if using data masking):
# {
#   "businessPartnerNumber": "B***9",
#   "email": "t***@e***.com"
# }

# Test extension endpoints (if applicable)
curl -X GET http://localhost:8181/management/v3/your-endpoint -H "X-Api-Key: password"
```

### Success Indicators

- ✅ Extension loads without errors
- ✅ 160+ service extensions loaded
- ✅ Database connection established
- ✅ Vault integration working
- ✅ All API endpoints responding
- ✅ Extension functionality verified
- ✅ **NEW**: Transformer integration working (if applicable)
- ✅ **NEW**: Live API responses show processed data
- ✅ **EXAMPLE**: businessPartnerNumber: "BPN123456789" → "B\*\*\*9"

## 📖 Resources

- [Full Creation Guide](EXTENSION_CREATION_GUIDE.md)
- [Existing Extensions](../edc-extensions/) - Study real implementations
- [EDC Documentation](https://eclipse-edc.github.io/docs/)
- [Helper Script](../create-extension.sh) - **Most up-to-date patterns**

## 💡 Quick Tips

### Development Workflow

- **Use helper script first**: `./create-extension.sh` has current best practices
- **Study existing extensions**: `bpn-validation`, `cx-policy`, `event-subscriber`
- **Start with production runtime**: Use `edc-controlplane-postgresql-hashicorp-vault` from the beginning
- **Set up infrastructure early**: Get PostgreSQL and Vault running first

### Configuration Best Practices

- **Use actual key values**: Specify `key` attribute in `@Setting` annotations
- **Test configuration keys**: Verify they work in production environment
- **Include all Tractus-X URLs**: STS, BDRS, MIW endpoints are required for production

### Testing Strategy

- **Unit tests first**: Use `DependencyInjectionExtension` for unit tests
- **Integration testing**: Test with full production runtime
- **Live API validation**: Test extension with actual HTTP calls
- **Check extension count**: Verify 160+ extensions load in production

### Runtime Selection

- **Development**: `edc-runtime-memory` for basic functionality only
- **Production**: `edc-controlplane-postgresql-hashicorp-vault` for Tractus-X compatibility
- **Infrastructure**: Docker containers for PostgreSQL (5433) and Vault (8200)

### Common Pitfalls to Avoid

- Using memory runtime for production extensions
- Missing Tractus-X specific configuration
- Not testing with live APIs
- Incomplete infrastructure setup
- **⚠️ NEW**: Missing transformer integration for API response processing
- **⚠️ NEW**: Incorrect JSON structure not following EDC namespace conventions
- **⚠️ NEW**: Not registering transformer with correct context ("management-api")

## 🎯 Complete Validation

After developing your extension, validate everything works correctly:

```bash
./FINAL-SUCCESS-REPORT.sh
```

**This comprehensive validation provides:**

- 📊 Infrastructure health verification (PostgreSQL, Vault, EDC APIs)
- 🔧 Extension loading confirmation (160+ extensions expected)
- 🧪 Live API testing with your extension functionality
- 📋 Production readiness assessment
- 🏆 Success metrics and achievement summary

**Use this validation to confirm:**

- Your extension loads without conflicts
- All Tractus-X services remain operational
- API responses show your extension's functionality
- Production environment is stable and ready
- **⚠️ NEW**: Using plain property names instead of EDC_NAMESPACE + "properties"
