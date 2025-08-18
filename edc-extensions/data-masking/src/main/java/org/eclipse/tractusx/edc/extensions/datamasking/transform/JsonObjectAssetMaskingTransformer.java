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

package org.eclipse.tractusx.edc.extensions.datamasking.transform;

import jakarta.json.JsonBuilderFactory;
import jakarta.json.JsonObject;
import org.eclipse.edc.connector.controlplane.asset.spi.domain.Asset;
import org.eclipse.edc.jsonld.spi.transformer.AbstractJsonLdTransformer;
import org.eclipse.edc.transform.spi.TransformerContext;
import org.eclipse.tractusx.edc.extensions.datamasking.DataMaskingService;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.Map;

import static org.eclipse.edc.jsonld.spi.JsonLdKeywords.ID;
import static org.eclipse.edc.jsonld.spi.JsonLdKeywords.TYPE;
import static org.eclipse.edc.spi.constants.CoreConstants.EDC_NAMESPACE;

/**
 * Transformer that applies data masking to Asset objects when converting to
 * JSON
 */
public class JsonObjectAssetMaskingTransformer extends AbstractJsonLdTransformer<Asset, JsonObject> {

    private final JsonBuilderFactory jsonFactory;
    private final DataMaskingService maskingService;

    public JsonObjectAssetMaskingTransformer(JsonBuilderFactory jsonFactory, DataMaskingService maskingService) {
        super(Asset.class, JsonObject.class);
        this.jsonFactory = jsonFactory;
        this.maskingService = maskingService;
    }

    @Override
    public @Nullable JsonObject transform(@NotNull Asset asset, @NotNull TransformerContext context) {
        // Debug logging to track transformer invocation
        System.out
                .println("🔍 [DEBUG] JsonObjectAssetMaskingTransformer.transform() called for asset: " + asset.getId());
        System.out.println("🔍 [DEBUG] Asset properties count: " + asset.getProperties().size());
        System.out.println("🔍 [DEBUG] Asset properties: " + asset.getProperties());

        var builder = jsonFactory.createObjectBuilder();

        // Add basic asset metadata
        builder.add(ID, asset.getId());
        builder.add(TYPE, "Asset");

        // Transform and mask properties
        var propertiesBuilder = jsonFactory.createObjectBuilder();
        for (Map.Entry<String, Object> entry : asset.getProperties().entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();

            if (value instanceof String stringValue) {
                // Apply masking to sensitive fields
                String maskedValue = maskingService.maskSensitiveData(key, stringValue);
                propertiesBuilder.add(key, maskedValue);

                // Debug logging for masking
                if (!stringValue.equals(maskedValue)) {
                    System.out.println("🔒 [MASKED] " + key + ": " + stringValue + " -> " + maskedValue);
                }
            } else {
                // For non-string values, add as-is (could be enhanced for complex objects)
                propertiesBuilder.add(key, value.toString());
            }
        }
        builder.add(EDC_NAMESPACE + "properties", propertiesBuilder.build());

        // Add data address if present (without masking - typically contains technical
        // data)
        if (asset.getDataAddress() != null) {
            var dataAddressBuilder = jsonFactory.createObjectBuilder();
            dataAddressBuilder.add(TYPE, "DataAddress");

            for (Map.Entry<String, Object> entry : asset.getDataAddress().getProperties().entrySet()) {
                dataAddressBuilder.add(entry.getKey(), entry.getValue().toString());
            }
            builder.add(EDC_NAMESPACE + "dataAddress", dataAddressBuilder.build());
        }

        var result = builder.build();
        System.out.println("✅ [DEBUG] JsonObjectAssetMaskingTransformer completed for asset: " + asset.getId());
        System.out.println("✅ [DEBUG] Resulting JSON: " + result.toString());
        return result;
    }
}
