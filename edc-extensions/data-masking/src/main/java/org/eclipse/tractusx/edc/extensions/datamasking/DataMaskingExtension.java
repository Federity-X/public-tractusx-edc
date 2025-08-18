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

import jakarta.json.Json;
import org.eclipse.edc.runtime.metamodel.annotation.Extension;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provider;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.event.EventRouter;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.transform.spi.TypeTransformerRegistry;
import org.eclipse.tractusx.edc.extensions.datamasking.transform.JsonObjectAssetMaskingTransformer;

@Extension(value = "Data Masking Extension", categories = { "security", "privacy", "dataplane" })
public class DataMaskingExtension implements ServiceExtension {

    public static final String NAME = "Data Masking Extension";

    @Setting(value = "Enable data masking", key = "edc.datamasking.enabled", defaultValue = "true")
    public static final String MASKING_ENABLED = "edc.datamasking.enabled";

    @Setting(value = "Masking strategy: PARTIAL, FULL, HASH", key = "edc.datamasking.strategy", defaultValue = "PARTIAL")
    public static final String MASKING_STRATEGY = "edc.datamasking.strategy";

    @Setting(value = "Comma-separated list of field names to mask", key = "edc.datamasking.fields", defaultValue = "email,name,firstName,lastName,ssn,phone,creditCard")
    public static final String MASKING_FIELDS = "edc.datamasking.fields";

    @Setting(value = "Enable audit logging of masking operations", key = "edc.datamasking.audit.enabled", defaultValue = "true")
    public static final String AUDIT_ENABLED = "edc.datamasking.audit.enabled";

    @Setting(value = "Custom regex patterns for sensitive data detection (JSON format)", key = "edc.datamasking.patterns", required = false)
    public static final String CUSTOM_PATTERNS = "edc.datamasking.patterns";

    @Inject
    private Monitor monitor;

    @Inject
    private EventRouter eventRouter;

    @Inject
    private TypeTransformerRegistry transformerRegistry;

    @Override
    public String name() {
        return NAME;
    }

    @Override
    public void initialize(ServiceExtensionContext context) {
        var enabled = context.getSetting(MASKING_ENABLED, "true");

        if (!"true".equalsIgnoreCase(enabled)) {
            monitor.info("Data masking is disabled");
            return;
        }

        var strategy = context.getSetting(MASKING_STRATEGY, "PARTIAL");
        var fields = context.getSetting(MASKING_FIELDS, "email,name,firstName,lastName,ssn,phone,creditCard");
        var auditEnabled = context.getSetting(AUDIT_ENABLED, "true");

        monitor.info("Initializing Data Masking Extension with strategy: " + strategy + ", fields: " + fields);

        // Register event subscriber for audit logging if enabled
        if ("true".equalsIgnoreCase(auditEnabled)) {
            eventRouter.register(DataMaskingEvent.class, new DataMaskingAuditSubscriber(monitor));
        }

        // Register the asset masking transformer
        monitor.info("Creating and registering Asset masking transformer...");
        var jsonFactory = Json.createBuilderFactory(null);
        var maskingService = createDataMaskingService(context);
        var assetTransformer = new JsonObjectAssetMaskingTransformer(jsonFactory, maskingService);

        // Register with management-api context specifically (only if transformer
        // registry is available)
        if (transformerRegistry != null) {
            monitor.info("Registering Asset transformer with Management API TypeTransformerRegistry...");
            var managementApiTransformerRegistry = transformerRegistry.forContext("management-api");
            if (managementApiTransformerRegistry != null) {
                managementApiTransformerRegistry.register(assetTransformer);
                monitor.info("Asset masking transformer registered successfully with management-api context");
            } else {
                monitor.info(
                        "Management API TypeTransformerRegistry context not available - skipping transformer registration");
            }
        } else {
            monitor.info(
                    "TypeTransformerRegistry not available (test environment) - skipping transformer registration");
        }

        monitor.info("Data Masking Extension initialized successfully");
    }

    @Provider
    public DataMaskingService createDataMaskingService(ServiceExtensionContext context) {
        var strategy = context.getSetting(MASKING_STRATEGY, "PARTIAL");
        var fields = context.getSetting(MASKING_FIELDS,
                "email,name,firstName,lastName,ssn,phone,creditCard,personalId,taxId,businessPartnerNumber");
        var auditEnabled = context.getSetting(AUDIT_ENABLED, "true");

        var config = DataMaskingConfig.builder()
                .strategy(MaskingStrategy.valueOf(strategy.toUpperCase()))
                .fieldsToMask(fields.split(","))
                .auditEnabled("true".equalsIgnoreCase(auditEnabled))
                .build();

        return new DataMaskingServiceImpl(monitor, config);
    }
}
