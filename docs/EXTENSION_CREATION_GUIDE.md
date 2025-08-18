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
    // implementation(libs.edc.spi.catalog)
    // implementation(libs.edc.spi.contract)
    // implementation(libs.edc.spi.management.api)

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

    @Setting(value = "My custom setting description", required = false)
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

import org.eclipse.edc.junit.extensions.EdcExtension;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(EdcExtension.class)
class MyCustomExtensionTest {

    @Test
    void shouldInitializeExtension(MyCustomExtension extension, EdcExtension runtime) {
        assertThat(extension.name()).isEqualTo("My Custom Extension");
    }

    @Test
    void shouldProvideCustomService(EdcExtension runtime) {
        var service = runtime.getContext().getService(MyCustomService.class);

        assertThat(service).isNotNull();
        assertThat(service.getCustomData()).isEqualTo("Custom data from service");
    }
}
```

### Step 7: Register Extension in settings.gradle.kts

Add your extension to the root `settings.gradle.kts`:

```kotlin
// Add this line with the other edc-extensions includes
include(":edc-extensions:my-custom-extension")
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
    @Setting(value = "Custom timeout in seconds", defaultValue = "30")
    int timeout,

    @Setting(value = "Enable custom feature", defaultValue = "false")
    boolean enableFeature
) {
}
```

## 🔍 Common Extension Types in Tractus-X

1. **Policy Extensions** - Add custom policy evaluation logic
2. **Data Processing Extensions** - Transform or validate data
3. **Protocol Extensions** - Implement custom communication protocols
4. **Storage Extensions** - Add custom persistence mechanisms
5. **Authentication Extensions** - Custom identity verification
6. **Monitoring Extensions** - Custom metrics and observability

## ✅ Best Practices

1. **Follow naming conventions**: Use kebab-case for directories, PascalCase for classes
2. **Add comprehensive tests**: Unit tests, integration tests, and documentation
3. **Use dependency injection**: Leverage EDC's `@Inject` annotation
4. **Handle configuration**: Use `@Setting` annotations for configurable values
5. **Add logging**: Use the injected `Monitor` for consistent logging
6. **Document your extension**: Create a README.md explaining purpose and usage
7. **Follow licensing**: Include proper Apache 2.0 license headers

## 🚀 Adding Extension to Runtime

To include your extension in a runtime, add it to the runtime's `build.gradle.kts`:

```kotlin
dependencies {
    implementation(project(":edc-extensions:my-custom-extension"))
}
```

## 📖 Additional Resources

- [Eclipse EDC Extension Documentation](https://eclipse-edc.github.io/docs/#/developer/decision-records/2022-02-03-extension-model/)
- [Tractus-X EDC Developer Documentation](docs/development/)
- [Existing Extensions Examples](edc-extensions/)

This guide provides a complete foundation for creating extensions in the Tractus-X EDC project. Follow the patterns established by existing extensions and adapt them to your specific use case.
