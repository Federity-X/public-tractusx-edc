# Extension Development Quick Reference

## 🚀 Quick Start

```bash
# 1. Create a new extension using the helper script
./create-extension.sh my-custom-extension

# 2. Build and test
./gradlew :edc-extensions:my-custom-extension:build

# 3. Include in runtime
# Add to your runtime's build.gradle.kts:
# implementation(project(":edc-extensions:my-custom-extension"))
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
    │   │   └── MyServiceImpl.java        # Service implementation
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

## 🐛 Debugging Tips

1. **Enable debug logging**: `edc.monitor.level=DEBUG`
2. **Check service registration**: Look for your service in startup logs
3. **Verify dependencies**: Ensure all `@Inject` fields are resolved
4. **Test with real runtime**: Verify integration beyond unit tests
5. **Check extension loading**: Look for extension name in startup sequence
6. **Validate configuration**: Ensure all required settings are provided
7. **Use proper test extension**: `DependencyInjectionExtension` for unit tests

## 🚀 Runtime Integration

```kotlin
// Direct inclusion in runtime
dependencies {
    implementation(project(":edc-extensions:my-extension"))
}

// With BOM and exclusions
configurations.all {
    exclude(group = "org.eclipse.edc", module = "conflicting-module")
}

dependencies {
    runtimeOnly(libs.edc.bom.controlplane.base)
    implementation(project(":edc-extensions:my-extension"))
}

// Multi-module extension registration in settings.gradle.kts
include(":edc-extensions:my-extension")
include(":edc-extensions:my-extension:my-extension-api")
include(":edc-extensions:my-extension:my-extension-core")
```

## 📖 Resources

- [Full Creation Guide](EXTENSION_CREATION_GUIDE.md)
- [Existing Extensions](../edc-extensions/) - Study real implementations
- [EDC Documentation](https://eclipse-edc.github.io/docs/)
- [Helper Script](../create-extension.sh) - **Most up-to-date patterns**

## 💡 Quick Tips

- **Use helper script first**: `./create-extension.sh` has current best practices
- **Study existing extensions**: `bpn-validation`, `cx-policy`, `event-subscriber`
- **Check base runtime inclusions**: Many extensions auto-included via `edc-controlplane-base`
- **Test configuration keys**: Use actual key values in `@Setting` annotations
- **Use categories**: Organize extensions with `@Extension(categories = {...})`
