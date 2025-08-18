/********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
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

package org.eclipse.tractusx.edc.extensions.datamasking;

import org.eclipse.edc.junit.extensions.DependencyInjectionExtension;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

@ExtendWith(DependencyInjectionExtension.class)
class DataMaskingExtensionTest {

    @Test
    void shouldInitializeExtension(DataMaskingExtension extension, ServiceExtensionContext context) {
        extension.initialize(context);
        assertEquals("Data Masking Extension", extension.name());
    }

    @Test
    void shouldProvideDataMaskingService(DataMaskingExtension extension, ServiceExtensionContext context) {
        var service = extension.createDataMaskingService(context);

        assertNotNull(service);
        assertTrue(service.shouldMaskField("email"));
        assertFalse(service.shouldMaskField("regularField"));
    }

    @Test
    void shouldMaskSensitiveData() {
        var config = DataMaskingConfig.builder()
                .strategy(MaskingStrategy.PARTIAL)
                .fieldsToMask(new String[] { "email", "name" })
                .auditEnabled(false)
                .build();

        // Use a test monitor implementation instead of mock
        var monitor = new TestMonitor();
        var service = new DataMaskingServiceImpl(monitor, config);

        // Test email masking
        String maskedEmail = service.maskValue("john.doe@example.com", "email");
        assertTrue(maskedEmail.contains("***"));
        assertTrue(maskedEmail.contains("@"));

        // Test name masking
        String maskedName = service.maskValue("John Doe", "name");
        assertTrue(maskedName.contains("***"));
        assertTrue(maskedName.startsWith("J"));
    }

    @Test
    void shouldMaskJsonData() {
        var config = DataMaskingConfig.builder()
                .strategy(MaskingStrategy.PARTIAL)
                .fieldsToMask(new String[] { "email", "name" })
                .auditEnabled(false)
                .build();

        var service = new DataMaskingServiceImpl(new TestMonitor(), config);

        String jsonData = "{\"email\":\"john@example.com\",\"name\":\"John Doe\",\"age\":30}";
        String maskedJson = service.maskJsonData(jsonData);

        assertTrue(maskedJson.contains("***"));
        assertTrue(maskedJson.contains("\"age\":30")); // Non-sensitive field should remain
    }

    @Test
    void shouldHandleDifferentMaskingStrategies() {
        var monitor = new TestMonitor();

        // Test FULL strategy
        var fullConfig = DataMaskingConfig.builder()
                .strategy(MaskingStrategy.FULL)
                .fieldsToMask(new String[] { "email" })
                .build();
        var fullService = new DataMaskingServiceImpl(monitor, fullConfig);
        assertEquals("***", fullService.maskValue("john@example.com", "email"));

        // Test HASH strategy
        var hashConfig = DataMaskingConfig.builder()
                .strategy(MaskingStrategy.HASH)
                .fieldsToMask(new String[] { "email" })
                .build();
        var hashService = new DataMaskingServiceImpl(monitor, hashConfig);
        String hashedValue = hashService.maskValue("john@example.com", "email");
        assertTrue(hashedValue.startsWith("HASH_"));
    }

    /**
     * Simple test monitor implementation for testing
     */
    private static class TestMonitor implements Monitor {
        @Override
        public void info(String message, Throwable... errors) {
            // No-op for testing
        }

        @Override
        public void warning(String message, Throwable... errors) {
            // No-op for testing
        }

        @Override
        public void severe(String message, Throwable... errors) {
            // No-op for testing
        }

        @Override
        public void debug(String message, Throwable... errors) {
            // No-op for testing
        }
    }
}
