#!/bin/bash
# Extension Creation Helper Script for Tractus-X EDC
# Usage: ./create-extension.sh <extension-name> [<package-suffix>]
# Example: ./create-extension.sh data-transformer transformer

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[CREATE-EXT]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to convert kebab-case to PascalCase
to_pascal_case() {
    echo "$1" | sed -r 's/(^|-)([a-z])/\U\2/g'
}

# Function to convert kebab-case to camelCase
to_camel_case() {
    echo "$1" | sed -r 's/-([a-z])/\U\1/g'
}

# Function to validate extension name
validate_extension_name() {
    if [[ ! "$1" =~ ^[a-z][a-z0-9-]*$ ]]; then
        error "Extension name must be lowercase, start with a letter, and contain only letters, numbers, and hyphens"
    fi
}

# Main function
main() {
    local extension_name="${1:-}"
    local package_suffix="${2:-${extension_name}}"
    
    if [[ -z "$extension_name" ]]; then
        error "Usage: $0 <extension-name> [<package-suffix>]"
    fi
    
    validate_extension_name "$extension_name"
    
    local pascal_name
    pascal_name=$(to_pascal_case "$extension_name")
    local camel_name
    camel_name=$(to_camel_case "$extension_name")
    
    local extension_dir="${PROJECT_ROOT}/edc-extensions/${extension_name}"
    local java_package="org.eclipse.tractusx.edc.extensions.${package_suffix}"
    local java_dir="${extension_dir}/src/main/java/org/eclipse/tractusx/edc/extensions/${package_suffix}"
    local test_dir="${extension_dir}/src/test/java/org/eclipse/tractusx/edc/extensions/${package_suffix}"
    local resources_dir="${extension_dir}/src/main/resources"
    
    log "Creating extension: ${extension_name}"
    log "Pascal case name: ${pascal_name}"
    log "Java package: ${java_package}"
    
    # Check if extension already exists
    if [[ -d "$extension_dir" ]]; then
        error "Extension directory already exists: $extension_dir"
    fi
    
    # Create directory structure
    log "Creating directory structure..."
    mkdir -p "$java_dir"
    mkdir -p "$test_dir"
    mkdir -p "${resources_dir}/META-INF/services"
    
    # Create build.gradle.kts
    log "Creating build.gradle.kts..."
    cat > "${extension_dir}/build.gradle.kts" << EOF
/********************************************************************************
 * Copyright (c) $(date +%Y) Contributors to the Eclipse Foundation
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
    \`java-library\`
    \`maven-publish\`
}

dependencies {
    implementation(project(\":spi:core-spi\"))
    implementation(project(\":core:core-utils\"))
    implementation(libs.jakartaJson)
    
    testImplementation(libs.edc.junit)
    testImplementation(libs.mockito.core)
    testImplementation(libs.assertj.core)
}
EOF

    # Create main extension class
    log "Creating main extension class..."
    cat > "${java_dir}/${pascal_name}Extension.java" << EOF
/********************************************************************************
 * Copyright (c) $(date +%Y) Contributors to the Eclipse Foundation
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

package ${java_package};

import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;

@Extension(value = "${pascal_name} Extension")
public class ${pascal_name}Extension implements ServiceExtension {

    @Setting(value = "Configuration setting for ${extension_name}", required = false)
    public static final String ${camel_name^^}_SETTING = "edc.${extension_name}.setting";

    @Inject
    private Monitor monitor;

    @Override
    public String name() {
        return "${pascal_name} Extension";
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var setting = context.getSetting(${camel_name^^}_SETTING, "default-value");
        monitor.info("Initializing ${pascal_name} Extension with setting: " + setting);
        
        // TODO: Initialize your extension logic here
    }

    @Override
    public void start() {
        monitor.info("${pascal_name} Extension started successfully");
    }

    @Override
    public void shutdown() {
        monitor.info("${pascal_name} Extension shutting down");
    }

    @Provider
    public ${pascal_name}Service create${pascal_name}Service(ServiceExtensionContext context) {
        return new ${pascal_name}ServiceImpl(monitor);
    }
}
EOF

    # Create service interface
    log "Creating service interface..."
    cat > "${java_dir}/${pascal_name}Service.java" << EOF
/********************************************************************************
 * Copyright (c) $(date +%Y) Contributors to the Eclipse Foundation
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

package ${java_package};

/**
 * Service interface for ${pascal_name} functionality.
 */
public interface ${pascal_name}Service {
    
    /**
     * Performs the main operation of this service.
     *
     * @param input the input parameter
     * @return the result of the operation
     */
    String processData(String input);
    
    /**
     * Checks if the service is available.
     *
     * @return true if the service is available, false otherwise
     */
    boolean isAvailable();
}
EOF

    # Create service implementation
    log "Creating service implementation..."
    cat > "${java_dir}/${pascal_name}ServiceImpl.java" << EOF
/********************************************************************************
 * Copyright (c) $(date +%Y) Contributors to the Eclipse Foundation
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

package ${java_package};

import org.eclipse.edc.spi.monitor.Monitor;

public class ${pascal_name}ServiceImpl implements ${pascal_name}Service {
    
    private final Monitor monitor;
    
    public ${pascal_name}ServiceImpl(Monitor monitor) {
        this.monitor = monitor;
    }
    
    @Override
    public String processData(String input) {
        monitor.debug("Processing data with ${pascal_name}Service: " + input);
        // TODO: Implement your business logic here
        return "Processed: " + input;
    }
    
    @Override
    public boolean isAvailable() {
        return true;
    }
}
EOF

    # Create service extension registration
    log "Creating service extension registration..."
    cat > "${resources_dir}/META-INF/services/org.eclipse.edc.spi.system.ServiceExtension" << EOF
#################################################################################
#  Copyright (c) $(date +%Y) Contributors to the Eclipse Foundation
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

${java_package}.${pascal_name}Extension
EOF

    # Create test class
    log "Creating test class..."
    cat > "${test_dir}/${pascal_name}ExtensionTest.java" << EOF
/********************************************************************************
 * Copyright (c) $(date +%Y) Contributors to the Eclipse Foundation
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

package ${java_package};

import org.eclipse.edc.junit.extensions.EdcExtension;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(EdcExtension.class)
class ${pascal_name}ExtensionTest {

    @Test
    void shouldInitializeExtension(${pascal_name}Extension extension) {
        assertThat(extension.name()).isEqualTo("${pascal_name} Extension");
    }

    @Test
    void shouldProvide${pascal_name}Service(EdcExtension runtime) {
        var service = runtime.getContext().getService(${pascal_name}Service.class);
        
        assertThat(service).isNotNull();
        assertThat(service.isAvailable()).isTrue();
        assertThat(service.processData("test")).isEqualTo("Processed: test");
    }
}
EOF

    # Create README
    log "Creating README.md..."
    cat > "${extension_dir}/README.md" << EOF
# ${pascal_name} Extension

## Overview

The ${pascal_name} Extension provides functionality for [describe your extension's purpose].

## Features

- [Feature 1]
- [Feature 2]
- [Feature 3]

## Configuration

| Setting | Description | Default Value | Required |
|---------|-------------|---------------|----------|
| \`edc.${extension_name}.setting\` | [Description of setting] | \`default-value\` | No |

## Usage

### Basic Usage

\`\`\`java
@Inject
private ${pascal_name}Service ${camel_name}Service;

public void someMethod() {
    String result = ${camel_name}Service.processData("input");
    // Use the result
}
\`\`\`

### Configuration Example

\`\`\`properties
edc.${extension_name}.setting=custom-value
\`\`\`

## Development

### Building

\`\`\`bash
./gradlew :edc-extensions:${extension_name}:build
\`\`\`

### Testing

\`\`\`bash
./gradlew :edc-extensions:${extension_name}:test
\`\`\`

## Integration

Add this extension to your runtime by including it in your \`build.gradle.kts\`:

\`\`\`kotlin
dependencies {
    implementation(project(\":edc-extensions:${extension_name}\"))
}
\`\`\`
EOF

    # Add to settings.gradle.kts
    log "Adding extension to settings.gradle.kts..."
    if ! grep -q "include(\":edc-extensions:${extension_name}\")" "${PROJECT_ROOT}/settings.gradle.kts"; then
        # Find the last edc-extensions include and add after it
        sed -i "/include(\":edc-extensions:.*\")/a\\include(\":edc-extensions:${extension_name}\")" "${PROJECT_ROOT}/settings.gradle.kts"
    else
        warn "Extension already included in settings.gradle.kts"
    fi
    
    log "✅ Extension '${extension_name}' created successfully!"
    echo ""
    echo "📁 Extension location: ${extension_dir}"
    echo "📦 Java package: ${java_package}"
    echo "🏷️  Extension class: ${pascal_name}Extension"
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Implement your business logic in ${pascal_name}ServiceImpl"
    echo "   2. Add additional dependencies to build.gradle.kts if needed"
    echo "   3. Update the README.md with specific documentation"
    echo "   4. Build and test: ./gradlew :edc-extensions:${extension_name}:build"
    echo "   5. Include in a runtime's build.gradle.kts to use it"
    echo ""
    echo "📚 See docs/EXTENSION_CREATION_GUIDE.md for detailed documentation"
}

# Execute main function with all arguments
main "$@"
