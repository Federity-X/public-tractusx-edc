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
@Extension(value = "My Extension")           // Marks the main extension class
@Inject                                      // Inject dependencies
@Provider                                    // Provide services to other extensions
@Setting(value = "Description", required = false) // Configuration settings
```

## 📝 Extension Template

```java
@Extension(value = "My Extension")
public class MyExtension implements ServiceExtension {

    @Setting(value = "My setting", required = false)
    public static final String MY_SETTING = "edc.my.setting";

    @Inject
    private Monitor monitor;

    @Override
    public String name() {
        return "My Extension";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
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

// Policy engine
implementation(libs.edc.spi.policyengine)

// Management API
implementation(libs.edc.spi.management.api)

// JSON processing
implementation(libs.jakartaJson)

// Testing
testImplementation(libs.edc.junit)
testImplementation(libs.mockito.core)
testImplementation(libs.assertj.core)
```

## 🧪 Testing Pattern

```java
@ExtendWith(EdcExtension.class)
class MyExtensionTest {

    @Test
    void shouldInitializeExtension(MyExtension extension) {
        assertThat(extension.name()).isEqualTo("My Extension");
    }

    @Test
    void shouldProvideService(EdcExtension runtime) {
        var service = runtime.getContext().getService(MyService.class);
        assertThat(service).isNotNull();
    }
}
```

## ⚙️ Configuration

```java
// In extension class
@Setting(value = "Description", required = false, defaultValue = "default")
public static final String SETTING_KEY = "edc.my.setting";

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
public MyApiController createApiController() {
    return new MyApiController(webService, monitor);
}
```

### Policy Function

```java
@Provider
public PolicyFunction createPolicyFunction() {
    return new MyPolicyFunction();
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
4. **Test in isolation**: Use `EdcExtension` for unit testing

## 📖 Resources

- [Full Creation Guide](EXTENSION_CREATION_GUIDE.md)
- [Existing Extensions](../edc-extensions/)
- [EDC Documentation](https://eclipse-edc.github.io/docs/)
- [Helper Script](../create-extension.sh)
