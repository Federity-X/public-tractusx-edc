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
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration test for the Data Masking Extension that tests the complete functionality
 * including runtime integration and API behavior.
 */
@ExtendWith(DependencyInjectionExtension.class)
class DataMaskingIntegrationTest {

    @Test
    void shouldInitializeExtensionInRuntime(DataMaskingExtension extension, ServiceExtensionContext context) {
        // Verify the extension initializes properly
        extension.initialize(context);
        assertEquals("Data Masking Extension", extension.name());
        
        // Verify the service is provided
        var service = extension.createDataMaskingService(context);
        assertNotNull(service);
        
        // Test basic functionality
        assertTrue(service.shouldMaskField("email"));
        assertFalse(service.shouldMaskField("regularField"));
    }

    @Test
    void shouldMaskDataWithDifferentStrategies(ServiceExtensionContext context) {
        var extension = new DataMaskingExtension();
        
        // Test PARTIAL strategy
        context.getConfig().putString("edc.datamasking.strategy", "PARTIAL");
        var partialService = extension.createDataMaskingService(context);
        
        String partialResult = partialService.maskValue("john.doe@example.com", "email");
        assertTrue(partialResult.contains("***"));
        assertTrue(partialResult.contains("@"));
        assertNotEquals("john.doe@example.com", partialResult);
        
        // Test FULL strategy
        context.getConfig().putString("edc.datamasking.strategy", "FULL");
        var fullService = extension.createDataMaskingService(context);
        
        String fullResult = fullService.maskValue("john.doe@example.com", "email");
        assertEquals("***", fullResult);
        
        // Test HASH strategy
        context.getConfig().putString("edc.datamasking.strategy", "HASH");
        var hashService = extension.createDataMaskingService(context);
        
        String hashResult = hashService.maskValue("john.doe@example.com", "email");
        assertTrue(hashResult.startsWith("HASH_"));
    }

    @Test
    void shouldMaskJsonDataCorrectly(ServiceExtensionContext context) {
        var extension = new DataMaskingExtension();
        context.getConfig().putString("edc.datamasking.strategy", "PARTIAL");
        context.getConfig().putString("edc.datamasking.fields", "email,name");
        
        var service = extension.createDataMaskingService(context);
        
        String testJson = """
            {
                "email": "john.doe@example.com",
                "name": "John Doe",
                "age": 30,
                "address": "123 Main St"
            }
            """;
        
        String maskedJson = service.maskJsonData(testJson);
        
        // Verify sensitive fields are masked
        assertFalse(maskedJson.contains("john.doe@example.com"));
        assertFalse(maskedJson.contains("John Doe"));
        assertTrue(maskedJson.contains("***"));
        
        // Verify non-sensitive fields remain unchanged
        assertTrue(maskedJson.contains("30"));
        assertTrue(maskedJson.contains("123 Main St"));
    }

    @Test
    void shouldDetectSensitiveDataWithRegex(ServiceExtensionContext context) {
        var extension = new DataMaskingExtension();
        context.getConfig().putString("edc.datamasking.strategy", "PARTIAL");
        
        var service = extension.createDataMaskingService(context);
        
        // Test email detection
        String emailData = "Contact us at support@company.com";
        String maskedEmail = service.detectAndMaskSensitiveData(emailData);
        assertNotEquals(emailData, maskedEmail);
        assertTrue(maskedEmail.contains("***"));
        
        // Test phone number detection
        String phoneData = "Call us at +1-555-123-4567";
        String maskedPhone = service.detectAndMaskSensitiveData(phoneData);
        assertNotEquals(phoneData, maskedPhone);
        assertTrue(maskedPhone.contains("***"));
        
        // Test SSN detection
        String ssnData = "SSN: 123-45-6789";
        String maskedSSN = service.detectAndMaskSensitiveData(ssnData);
        assertNotEquals(ssnData, maskedSSN);
        assertTrue(maskedSSN.contains("***"));
    }

    @Test
    void shouldHandleConfigurationChanges(ServiceExtensionContext context) {
        var extension = new DataMaskingExtension();
        
        // Test with masking disabled
        context.getConfig().putString("edc.datamasking.enabled", "false");
        extension.initialize(context);
        
        // Test with custom fields
        context.getConfig().putString("edc.datamasking.enabled", "true");
        context.getConfig().putString("edc.datamasking.fields", "customField,anotherField");
        
        var service = extension.createDataMaskingService(context);
        
        assertTrue(service.shouldMaskField("customField"));
        assertTrue(service.shouldMaskField("anotherField"));
        assertFalse(service.shouldMaskField("email")); // Default field not in custom list
    }

    @Test
    void shouldProvideCorrectServiceName() {
        var extension = new DataMaskingExtension();
        assertEquals("Data Masking Extension", extension.name());
    }
    
    @Test
    void shouldMaskComplexJsonStructures(ServiceExtensionContext context) {
        var extension = new DataMaskingExtension();
        context.getConfig().putString("edc.datamasking.strategy", "PARTIAL");
        context.getConfig().putString("edc.datamasking.fields", "email,personalData");
        
        var service = extension.createDataMaskingService(context);
        
        String complexJson = """
            {
                "customers": [
                    {
                        "id": "CUST001",
                        "email": "alice@company.com",
                        "personalData": "Sensitive information",
                        "metadata": {
                            "created": "2025-01-01",
                            "email": "backup@company.com"
                        }
                    },
                    {
                        "id": "CUST002", 
                        "email": "bob@company.com",
                        "personalData": "More sensitive data"
                    }
                ]
            }
            """;
        
        String maskedJson = service.maskJsonData(complexJson);
        
        // Verify all email fields are masked
        assertFalse(maskedJson.contains("alice@company.com"));
        assertFalse(maskedJson.contains("backup@company.com"));
        assertFalse(maskedJson.contains("bob@company.com"));
        
        // Verify personalData fields are masked
        assertFalse(maskedJson.contains("Sensitive information"));
        assertFalse(maskedJson.contains("More sensitive data"));
        
        // Verify non-sensitive data remains
        assertTrue(maskedJson.contains("CUST001"));
        assertTrue(maskedJson.contains("CUST002"));
        assertTrue(maskedJson.contains("2025-01-01"));
        
        // Verify masking placeholders are present
        assertTrue(maskedJson.contains("***"));
    }
}
