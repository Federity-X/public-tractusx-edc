# Creating an Extension in Tractus-X EDC

T### Step 0: Choose the Right Runtime

#### ✅ **For Tractus-X Production Extensions:**

- **Use**: `edc-controlplane-postgresql-hashicorp-vault` for full compatibility
- **Includes**: PostgreSQL persistence, Vault secrets, all Tractus-X extensions (160+)
- **Required for**: BPN validation, agreement retirement, EDR index, data masking, etc.
- **Example**: Data Masking Extension successfully integrated and tested

#### For Development/Testing Only: explains how to create a new extension in the Tractus-X Eclipse Dataspace Connector (EDC) project.

## 📋 Prerequisites

- Java 21+
- Gradle 8.x
- Understanding of Eclipse EDC extension mechanism
- Familiarity with dependency injection patterns
- Docker (for production runtime testing)
- Basic understanding of PostgreSQL and HashiCorp Vault (for full Tractus-X integration)

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

### Step 0: Choose the Right Runtime

#### For Tractus-X Production Extensions:

- Use `edc-controlplane-postgresql-hashicorp-vault` for full compatibility
- Includes: PostgreSQL persistence, Vault secrets, all Tractus-X extensions
- Required for: BPN validation, agreement retirement, EDR index, etc.

#### For Simple Development/Testing:

- Use `edc-runtime-memory` for basic functionality
- Limitations: No persistence, no secrets management, limited Tractus-X features

#### Runtime Comparison:

| Runtime                                     | Use Case            | Tractus-X Features | Infrastructure     |
| ------------------------------------------- | ------------------- | ------------------ | ------------------ |
| edc-runtime-memory                          | Development/Testing | Basic              | None               |
| edc-controlplane-postgresql-hashicorp-vault | Production          | Full               | PostgreSQL + Vault |

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

### Step 2.5: Infrastructure Setup (For Production Runtimes)

**⚠️ Required for `edc-controlplane-postgresql-hashicorp-vault` runtime**

#### Required Services:

1. **PostgreSQL Database**:

   ```bash
   docker run --name edc-postgres \
     -e POSTGRES_DB=edc \
     -e POSTGRES_USER=edc \
     -e POSTGRES_PASSWORD=password \
     -p 5433:5432 -d postgres:13
   ```

2. **HashiCorp Vault**:

   ```bash
   docker run --name edc-vault \
     --cap-add=IPC_LOCK \
     -e 'VAULT_DEV_ROOT_TOKEN_ID=root' \
     -p 8200:8200 -d vault:latest
   ```

3. **Configure Vault Secrets** (required for OAuth):
   ```bash
   curl -X POST \
     -H "X-Vault-Token: root" \
     -d '{"data": {"secret": "test-client-secret"}}' \
     http://localhost:8200/v1/secret/data/test-clientid-alias
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

### Step 9: Production Runtime Integration

#### For Production Extensions (Tractus-X compatible):

1. **Add extension to production runtime** (`edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build.gradle.kts`):

   ```kotlin
   dependencies {
       // ... existing dependencies
       runtimeOnly(project(":edc-extensions:my-custom-extension"))
   }
   ```

2. **Create production configuration** (`tractus-x-config.properties`):

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
   edc.vault.hashicorp.api.secret.path=/v1/secret
   edc.vault.hashicorp.api.health.check.path=/v1/sys/health

   # API Endpoints
   web.http.default.port=8080
   web.http.default.path=/api
   web.http.management.port=8181
   web.http.management.path=/management
   web.http.protocol.port=8282
   web.http.protocol.path=/protocol
   web.http.public.port=8185
   web.http.public.path=/public
   web.http.control.port=9999
   web.http.control.path=/control

   # Tractus-X Specific Configuration
   edc.oauth.token.url=https://keycloak.example.com/auth/realms/miw_test/protocol/openid-connect/token
   edc.oauth.client.id=miw_private_client
   edc.oauth.private.key.alias=test-clientid-alias
   edc.oauth.certificate.alias=test-clientid-alias
   edc.oauth.provider.audience=miw_private_client

   tx.sts.oauth.token.url=https://sts.example.com/token
   tx.sts.oauth.client.id=sts-client
   tx.sts.oauth.client.secret.alias=sts-client-secret
   tx.sts.dim.url=https://dim.example.com

   tx.ssi.miw.url=https://miw.example.com
   tx.ssi.miw.authority.id=BPNL000000000001
   tx.ssi.oauth.token.url=https://keycloak.example.com/auth/realms/miw_test/protocol/openid-connect/token
   tx.ssi.oauth.client.id=miw_private_client
   tx.ssi.oauth.client.secret.alias=miw-client-secret

   tx.dpf.consumer.proxy.port=8186
   tx.edr.state-machine.iteration-wait-millis=1000
   tx.bdrs.server.url=https://bdrs.example.com

   # Your Extension Configuration
   edc.mycustom.setting=production-value
   ```

3. **Build production runtime**:

   ```bash
   ./gradlew :edc-controlplane:edc-controlplane-postgresql-hashicorp-vault:clean :edc-controlplane:edc-controlplane-postgresql-hashicorp-vault:shadowJar
   ```

4. **Run with full Tractus-X stack**:
   ```bash
   java -Dedc.fs.config=tractus-x-config.properties \
     -jar edc-controlplane/edc-controlplane-postgresql-hashicorp-vault/build/libs/edc-controlplane-postgresql-hashicorp-vault.jar
   ```

### Step 10: Production Testing and Validation

#### Verify Extension Loading:

**Check logs for:**

- Extension initialization message: "My Custom Extension started successfully"
- Total extensions loaded: "160+ service extensions" indicates full Tractus-X stack
- No ERROR or WARN messages related to your extension

#### Live API Testing:

```bash
# Test Management API
curl -X GET http://localhost:8181/management \
  -H "X-Api-Key: password"

# Test extension-specific endpoints
curl -X GET http://localhost:8181/management/v3/your-extension-endpoint \
  -H "X-Api-Key: password"

# Verify functionality
curl -X POST http://localhost:8181/management/v3/your-extension/test \
  -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

#### Production Validation Checklist:

- ✅ Extension loads without errors
- ✅ All required services initialized
- ✅ Database connection established (PostgreSQL)
- ✅ Vault integration working
- ✅ API endpoints responding
- ✅ Extension functionality verified
- ✅ No runtime warnings or errors

## � Troubleshooting

### Extension Not Loading

- **Check**: META-INF/services file path and content
- **Check**: Build dependencies and module inclusion in settings.gradle.kts
- **Check**: Runtime dependencies in target runtime's build.gradle.kts

### Configuration Issues

- **Missing Tractus-X URLs**: Add all required STS, BDRS, MIW endpoints
- **Database Connection**: Verify PostgreSQL is running on correct port (5433)
- **Vault Access**: Confirm Vault token and secret paths are correct

### Runtime Failures

- **Dependency Conflicts**: Use proper exclusions in build.gradle.kts
- **Missing Infrastructure**: Ensure PostgreSQL and Vault are running before starting EDC
- **Port Conflicts**: Check no other services using same ports (8181, 8200, 5433)

### API Testing Issues

- **Authentication**: Verify X-Api-Key header matches edc.api.auth.key configuration
- **Endpoints**: Confirm management API port (8181) is correct
- **Content-Type**: Include proper headers for POST requests

### Performance Issues

- **Extension Size**: Keep extensions lightweight (aim for < 50KB)
- **Initialization**: Avoid heavy operations in initialize() method
- **Dependencies**: Only include necessary dependencies

## �📚 Advanced Extension Patterns

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
11. **Choose appropriate runtime**: Use production runtime for Tractus-X compatibility
12. **Set up infrastructure**: Ensure PostgreSQL and Vault are running for production runtime
13. **Validate in production context**: Test with live APIs and full Tractus-X stack

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

### Option 1: Production Runtime (Recommended for Tractus-X)

Add it to `edc-controlplane-postgresql-hashicorp-vault` runtime's `build.gradle.kts`:

```kotlin
dependencies {
    runtimeOnly(project(":edc-extensions:my-custom-extension"))
}
```

**This is the recommended approach for Tractus-X extensions** as it provides:

- Full Tractus-X ecosystem compatibility
- PostgreSQL persistence
- Vault secrets management
- All required Tractus-X extensions (BPN validation, agreement retirement, etc.)

### Option 2: Development Runtime (Limited functionality)

For basic development only, add to `edc-runtime-memory`:

```kotlin
dependencies {
    implementation(project(":edc-extensions:my-custom-extension"))
}
```

**⚠️ Note**: Memory runtime has significant limitations for Tractus-X development.

### Option 3: Runtime Base Integration

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
6. **Start with production runtime**: Use `edc-controlplane-postgresql-hashicorp-vault` from the beginning for Tractus-X compatibility
7. **Set up infrastructure first**: Get PostgreSQL and Vault running before testing
8. **Use comprehensive configuration**: Include all Tractus-X specific URLs and parameters
9. **Validate with live APIs**: Test your extension with actual API calls, not just unit tests
10. **Monitor extension loading**: Check logs to ensure your extension loads with the 160+ other Tractus-X extensions

This guide provides a complete foundation for creating extensions in the Tractus-X EDC project. The helper script (`create-extension.sh`) is regularly updated and often contains more current patterns than manual examples, so prefer using it for new extensions.

## 🎯 Key Takeaways

**For Production-Ready Extensions:**

- Always use `edc-controlplane-postgresql-hashicorp-vault` runtime
- Set up Docker infrastructure (PostgreSQL + Vault)
- Use comprehensive Tractus-X configuration
- Test with live API endpoints
- Validate with full 160+ extension stack

**Common Mistakes to Avoid:**

- Using memory runtime for production extensions
- Incomplete Tractus-X configuration (missing STS, BDRS URLs)
- No infrastructure setup
- Only unit testing without live validation
- Not checking extension loading in logs
