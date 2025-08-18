# Creating an Extension in Tractus-X EDC

This guide explains how to create a new extension in the Tractus-X Eclipse Dataspace Connector (EDC) project.

## 📋 Prerequisites

- Java 21+
- Gradle 8.x
- Understanding of Eclipse EDC extension mechanism
- Familiarity with dependency injection patterns

## 🏗️ Extension Structure Overview

Tractus-X EDC extensions follow the Eclipse EDC extension pattern with this typical structure:

```
edc-extensions/
└── your-extension-name/
    ├── build.gradle.kts                    # Gradle build configuration
    ├── README.md                           # Extension documentation
    └── src/
        ├── main/
        │   ├── java/
        │   │   └── org/eclipse/tractusx/edc/...
        │   │       ├── YourExtension.java   # Main extension class
        │   │       ├── service/             # Service implementations
        │   │       ├── api/                 # API controllers (if needed)
        │   │       └── config/              # Configuration classes
        │   └── resources/
        │       └── META-INF/
        │           └── services/
        │               └── org.eclipse.edc.spi.system.ServiceExtension
        └── test/
            └── java/
                └── org/eclipse/tractusx/edc/...
                    ├── YourExtensionTest.java
                    └── integration/         # Integration tests
```

## 🚀 Step-by-Step Creation Process

### Step 1: Create Extension Directory Structure

```bash
# Navigate to the edc-extensions directory
cd edc-extensions

# Create your extension directory (use kebab-case naming)
mkdir my-custom-extension

# Create the standard directory structure
mkdir -p my-custom-extension/src/main/java/org/eclipse/tractusx/edc/extensions/mycustom
mkdir -p my-custom-extension/src/main/resources/META-INF/services
mkdir -p my-custom-extension/src/test/java/org/eclipse/tractusx/edc/extensions/mycustom
```

### Step 2: Create build.gradle.kts

Create `edc-extensions/my-custom-extension/build.gradle.kts`:

```kotlin
/********************************************************************************
 * Copyright (c) 2024 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ********************************************************************************/

plugins {
    `java-library`
    `maven-publish`  // Add if you want to publish the extension
}

dependencies {
    // Core EDC dependencies
    implementation(project(":spi:core-spi"))
    implementation(project(":core:core-utils"))

    // Add other EDC SPIs as needed
    implementation(libs.edc.spi.catalog)
    implementation(libs.edc.spi.contract)
    implementation(libs.edc.spi.policyengine)

    // External dependencies
    implementation(libs.jakartaJson)

    // Test dependencies
    testImplementation(libs.edc.junit)
    testImplementation(libs.mockito.core)
    testImplementation(libs.assertj.core)
}
```

### Step 3: Create the Main Extension Class

Create `src/main/java/org/eclipse/tractusx/edc/extensions/mycustom/MyCustomExtension.java`:

```java
/********************************************************************************
 * Copyright (c) 2024 Contributors to the Eclipse Foundation
 *
 * See the NOTICE file(s) distributed with this work for additional
 * information regarding copyright ownership.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Apache License, Version 2.0 which is available at
 * https://www.apache.org/licenses/LICENSE-2.0.
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 *
 * SPDX-License-Identifier: Apache-2.0
 ********************************************************************************/

package org.eclipse.tractusx.edc.extensions.mycustom;

import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.spi.monitor.Monitor;

@Extension(value = "My Custom Extension")
public class MyCustomExtension implements ServiceExtension {

    @Setting(value = "My custom setting description", required = false, key = "edc.mycustom.setting")
    public static final String MY_CUSTOM_SETTING = "edc.mycustom.setting";

    @Inject
    private Monitor monitor;

    // Inject other services as needed
    // @Inject
    // private SomeService someService;

    @Override
    public String name() {
        return "My Custom Extension";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var setting = context.getSetting(MY_CUSTOM_SETTING, "default-value");
        monitor.info("Initializing My Custom Extension with setting: " + setting);

        // Initialize your extension logic here
        // Register transformers, listeners, etc.
    }

    @Override
    public void start() {
        monitor.info("My Custom Extension started successfully");
    }

    @Override
    public void shutdown() {
        monitor.info("My Custom Extension shutting down");
    }

    // Provide services to other extensions
    @Provider
    public MyCustomService createMyCustomService(ServiceExtensionContext context) {
        return new MyCustomServiceImpl(monitor);
    }
}
```

### Step 4: Create Service Extension Registration File

Create `src/main/resources/META-INF/services/org.eclipse.edc.spi.system.ServiceExtension`:

```
#################################################################################
#  Copyright (c) 2024 Contributors to the Eclipse Foundation
#
#  See the NOTICE file(s) distributed with this work for additional
#  information regarding copyright ownership.
#
#  This program and the accompanying materials are made available under the
#  terms of the Apache License, Version 2.0 which is available at
#  https://www.apache.org/licenses/LICENSE-2.0.
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#  License for the specific language governing permissions and limitations
#  under the License.
#
#  SPDX-License-Identifier: Apache-2.0
#################################################################################

org.eclipse.tractusx.edc.extensions.mycustom.MyCustomExtension
```

### Step 5: Create Service Interface and Implementation

Create service interface `src/main/java/.../MyCustomService.java`:

```java
package org.eclipse.tractusx.edc.extensions.mycustom;

public interface MyCustomService {
    void performCustomOperation(String input);
    String getCustomData();
}
```

Create implementation `src/main/java/.../MyCustomServiceImpl.java`:

```java
package org.eclipse.tractusx.edc.extensions.mycustom;

import org.eclipse.edc.spi.monitor.Monitor;

public class MyCustomServiceImpl implements MyCustomService {

    private final Monitor monitor;

    public MyCustomServiceImpl(Monitor monitor) {
        this.monitor = monitor;
    }

    @Override
    public void performCustomOperation(String input) {
        monitor.debug("Performing custom operation with input: " + input);
        // Your implementation here
    }

    @Override
    public String getCustomData() {
        return "Custom data from service";
    }
}
```

### Step 6: Create Tests

Create `src/test/java/.../MyCustomExtensionTest.java`:

```java
package org.eclipse.tractusx.edc.extensions.mycustom;

import org.eclipse.edc.junit.extensions.DependencyInjectionExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

@ExtendWith(DependencyInjectionExtension.class)
class MyCustomExtensionTest {

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        // Register any required services for testing
        // context.registerService(SomeService.class, mock(SomeService.class));
    }

    @Test
    void shouldInitializeExtension(MyCustomExtension extension, ServiceExtensionContext context) {
        extension.initialize(context);
        assertThat(extension.name()).isEqualTo("My Custom Extension");
    }

    @Test
    void shouldProvideCustomService(MyCustomExtension extension, ServiceExtensionContext context) {
        extension.initialize(context);
        var service = extension.createMyCustomService(context);

        assertThat(service).isNotNull();
        assertThat(service.getCustomData()).isEqualTo("Custom data from service");
    }
}
```

### Step 7: Register Extension in settings.gradle.kts

Add your extension to the root `settings.gradle.kts`. For single-module extensions:

```kotlin
// Add this line with the other edc-extensions includes
include(":edc-extensions:my-custom-extension")
```

For multi-module extensions (like bpn-validation):

```kotlin
include(":edc-extensions:my-complex-extension")
include(":edc-extensions:my-complex-extension:my-extension-api")
include(":edc-extensions:my-complex-extension:my-extension-spi")
include(":edc-extensions:my-complex-extension:my-extension-core")
```

### Step 8: Build and Test

```bash
# Build your extension
./gradlew :edc-extensions:my-custom-extension:build

# Run tests
./gradlew :edc-extensions:my-custom-extension:test

# Build the entire project to ensure integration
./gradlew build
```

## 📚 Advanced Extension Patterns

### Multi-Module Extension

For complex extensions, you can create multiple modules:

```
edc-extensions/my-complex-extension/
├── build.gradle.kts
├── my-extension-api/
├── my-extension-spi/
├── my-extension-core/
└── my-extension-sql/
```

### Adding REST API Endpoints

If your extension needs REST endpoints:

```java
@Provider
public MyCustomApiController createApiController(ServiceExtensionContext context) {
    return new MyCustomApiController(monitor, myCustomService);
}
```

### Configuration Management

Use configuration classes for complex settings:

```java
@Settings
public record MyCustomConfig(
    @Setting(value = "Custom timeout in seconds", defaultValue = "30", key = "edc.mycustom.timeout")
    int timeout,

    @Setting(value = "Enable custom feature", defaultValue = "false", key = "edc.mycustom.enable")
    boolean enableFeature,

    @Setting(value = "Custom endpoint URL", required = false, key = "edc.mycustom.endpoint")
    String endpointUrl
) {
}
```

## 🧪 Testing Patterns

### Unit Testing with DependencyInjectionExtension

```java
@ExtendWith(DependencyInjectionExtension.class)
class MyExtensionTest {

    private final PolicyEngine policyEngine = mock();
    private final RuleBindingRegistry ruleBindingRegistry = mock();

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        context.registerService(PolicyEngine.class, policyEngine);
        context.registerService(RuleBindingRegistry.class, ruleBindingRegistry);
    }

    @Test
    void shouldInitializeExtension(ServiceExtensionContext context, MyExtension extension) {
        extension.initialize(context);

        verify(policyEngine).registerFunction(any(), any(), any(), any());
        verify(ruleBindingRegistry).bind(anyString(), anyString());
    }
}
```

### Integration Testing Patterns

For complex extensions that need full runtime context:

```java
@ExtendWith(DependencyInjectionExtension.class)
class MyExtensionIntegrationTest {

    @Test
    void shouldWorkInRuntimeContext(ServiceExtensionContext context) {
        // Setup required services
        var myService = new MyServiceImpl(context.getMonitor());
        context.registerService(MyService.class, myService);

        // Test extension behavior
        var extension = new MyExtension();
        extension.initialize(context);

        assertThat(extension.name()).isNotNull();
    }
}
```

## 📦 BOM (Bill of Materials) Usage

### Understanding BOMs

Tractus-X EDC uses BOMs to manage consistent dependency versions across modules:

```kotlin
dependencies {
    // BOMs provide coordinated dependency versions
    runtimeOnly(libs.edc.bom.controlplane.base)
    runtimeOnly(libs.edc.bom.controlplane.dcp)
    runtimeOnly(libs.edc.bom.federatedcatalog.base)

    // Your extension dependencies
    implementation(project(":edc-extensions:my-extension"))
}
```

### Available BOMs

- `edc-bom-controlplane-base` - Core control plane functionality
- `edc-bom-controlplane-dcp` - DCP (Dataspace Protocol) support
- `edc-bom-dataplane-base` - Core data plane functionality
- `edc-bom-federatedcatalog-base` - Federated catalog functionality

### Runtime Configuration Examples

Check existing runtime configurations for patterns:

```kotlin
// From edc-controlplane-base/build.gradle.kts
configurations.all {
    // Exclude conflicting modules
    exclude(group = "org.eclipse.edc", module = "edr-cache-api")
    exclude("org.eclipse.edc", "identity-trust-sts-remote-client")
}

dependencies {
    runtimeOnly(libs.edc.bom.controlplane.base)
    runtimeOnly(libs.edc.bom.controlplane.dcp)

    // Extensions are explicitly included
    implementation(project(":edc-extensions:bpn-validation"))
    implementation(project(":edc-extensions:cx-policy"))
    implementation(project(":edc-extensions:data-flow-properties-provider"))

    runtimeOnly(libs.bundles.edc.monitoring)
}
```

## 🔍 Common Extension Types in Tractus-X

1. **Policy Extensions** - Add custom policy evaluation logic (e.g., `cx-policy`)
2. **Data Processing Extensions** - Transform or validate data (e.g., `data-flow-properties-provider`)
3. **Protocol Extensions** - Implement custom communication protocols (e.g., `dcp`)
4. **Storage Extensions** - Add custom persistence mechanisms (e.g., `business-partner-store-sql`)
5. **Authentication Extensions** - Custom identity verification (e.g., `bdrs-client`)
6. **Monitoring Extensions** - Custom metrics and observability (e.g., `event-subscriber`)
7. **Validation Extensions** - Business rule validation (e.g., `bpn-validation`)

### Real Extension Examples

Study these existing extensions for patterns:

- **Multi-module**: `bpn-validation` (api/spi/core structure)
- **Policy engine**: `cx-policy` (constraint functions)
- **Service provider**: `bdrs-client` (external service integration)
- **Data transformation**: `data-flow-properties-provider`
- **Event handling**: `event-subscriber`

## ✅ Best Practices

1. **Follow naming conventions**: Use kebab-case for directories, PascalCase for classes
2. **Add comprehensive tests**: Unit tests, integration tests, and documentation
3. **Use dependency injection**: Leverage EDC's `@Inject` annotation
4. **Handle configuration**: Use `@Setting` annotations with proper `key` attributes
5. **Add logging**: Use the injected `Monitor` for consistent logging
6. **Document your extension**: Create a README.md explaining purpose and usage
7. **Follow licensing**: Include proper Apache 2.0 license headers
8. **Use extension categories**: Add categories in `@Extension` annotation for better organization
9. **Handle runtime conflicts**: Use proper exclusions when needed
10. **Test with real runtime**: Verify your extension works in actual runtime configurations

### Extension Categories

Categorize your extensions for better organization:

```java
@Extension(value = "My Custom Extension", categories = { "policy", "contract", "validation" })
public class MyCustomExtension implements ServiceExtension {
    // ...
}
```

Common categories:

- `"policy"` - Policy-related extensions
- `"contract"` - Contract negotiation extensions
- `"validation"` - Data validation extensions
- `"auth"` - Authentication/authorization extensions
- `"storage"` - Data storage extensions

## 🚀 Adding Extension to Runtime

To include your extension in a runtime, you have several options:

### Option 1: Direct Dependency

Add it to the runtime's `build.gradle.kts`:

```kotlin
dependencies {
    implementation(project(":edc-extensions:my-custom-extension"))
}
```

### Option 2: Runtime Base Integration

Many extensions are automatically included via base runtime modules. Check if your extension is already included in:

- `edc-controlplane-base/build.gradle.kts`
- `edc-dataplane-base/build.gradle.kts`

### Option 3: BOM (Bill of Materials) Usage

For runtime modules using BOMs:

```kotlin
dependencies {
    runtimeOnly(libs.edc.bom.controlplane.base)
    runtimeOnly(libs.edc.bom.controlplane.dcp)

    // Your extension
    implementation(project(":edc-extensions:my-custom-extension"))
}
```

### Handling Dependency Conflicts

If your extension conflicts with existing ones:

```kotlin
configurations.all {
    exclude(group = "org.eclipse.edc", module = "conflicting-module")
}
```

## 📖 Additional Resources

- [Extension Quick Reference](EXTENSION_QUICK_REFERENCE.md) - Quick commands and patterns
- [Eclipse EDC Extension Documentation](https://eclipse-edc.github.io/docs/#/developer/decision-records/2022-02-03-extension-model/)
- [Tractus-X EDC Developer Documentation](development/)
- [Existing Extensions Examples](../edc-extensions/) - Study real implementations
- [Helper Script](../create-extension.sh) - Automated extension creation (most up-to-date patterns)

### 💡 Pro Tips

1. **Use the helper script**: `./create-extension.sh my-extension` generates current best practices
2. **Study existing extensions**: Look at `bpn-validation`, `cx-policy`, and `event-subscriber` for patterns
3. **Check runtime inclusions**: Verify if your extension is automatically included in base runtimes
4. **Test with real runtimes**: Don't just unit test - verify integration with actual runtime configurations
5. **Keep dependencies minimal**: Only include what your extension actually needs

This guide provides a complete foundation for creating extensions in the Tractus-X EDC project. The helper script (`create-extension.sh`) is regularly updated and often contains more current patterns than manual examples, so prefer using it for new extensions.
