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
import jakarta.json.JsonObject;
import jakarta.json.JsonObjectBuilder;
import jakarta.json.JsonValue;
import org.eclipse.edc.spi.monitor.Monitor;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;

/**
 * Implementation of the DataMaskingService.
 */
public class DataMaskingServiceImpl implements DataMaskingService {

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$");

    private static final Pattern PHONE_PATTERN = Pattern.compile(
            "^[+]?[1-9]?[0-9]{7,15}$");

    private static final Pattern SSN_PATTERN = Pattern.compile(
            "^\\d{3}-?\\d{2}-?\\d{4}$");

    private final Monitor monitor;
    private final DataMaskingConfig config;

    public DataMaskingServiceImpl(Monitor monitor, DataMaskingConfig config) {
        this.monitor = monitor;
        this.config = config;
    }

    @Override
    public Map<String, Object> maskData(Map<String, Object> data) {
        Map<String, Object> maskedData = new HashMap<>();

        for (Map.Entry<String, Object> entry : data.entrySet()) {
            String key = entry.getKey();
            Object value = entry.getValue();

            if (value instanceof String stringValue) {
                if (shouldMaskField(key) || isSensitiveValue(stringValue)) {
                    String maskedValue = maskValue(stringValue, key);
                    maskedData.put(key, maskedValue);

                    if (config.isAuditEnabled()) {
                        monitor.debug("Masked field: " + key);
                    }
                } else {
                    maskedData.put(key, value);
                }
            } else if (value instanceof Map<?, ?> nestedMap) {
                // Recursively mask nested objects
                @SuppressWarnings("unchecked")
                Map<String, Object> nestedStringMap = (Map<String, Object>) nestedMap;
                maskedData.put(key, maskData(nestedStringMap));
            } else {
                maskedData.put(key, value);
            }
        }

        return maskedData;
    }

    @Override
    public String maskJsonData(String jsonData) {
        try {
            JsonObject jsonObject = Json.createReader(new java.io.StringReader(jsonData)).readObject();
            JsonObject maskedJson = maskJsonObject(jsonObject);
            return maskedJson.toString();
        } catch (Exception e) {
            monitor.warning("Failed to parse JSON for masking, returning original data", e);
            return jsonData;
        }
    }

    private JsonObject maskJsonObject(JsonObject jsonObject) {
        JsonObjectBuilder builder = Json.createObjectBuilder();

        for (Map.Entry<String, JsonValue> entry : jsonObject.entrySet()) {
            String key = entry.getKey();
            JsonValue value = entry.getValue();

            if (value.getValueType() == JsonValue.ValueType.STRING) {
                String stringValue = ((jakarta.json.JsonString) value).getString();
                if (shouldMaskField(key) || isSensitiveValue(stringValue)) {
                    String maskedValue = maskValue(stringValue, key);
                    builder.add(key, maskedValue);

                    if (config.isAuditEnabled()) {
                        monitor.debug("Masked JSON field: " + key);
                    }
                } else {
                    builder.add(key, value);
                }
            } else if (value.getValueType() == JsonValue.ValueType.OBJECT) {
                JsonObject nestedObject = (JsonObject) value;
                builder.add(key, maskJsonObject(nestedObject));
            } else {
                builder.add(key, value);
            }
        }

        return builder.build();
    }

    @Override
    public boolean shouldMaskField(String fieldName) {
        if (fieldName == null) {
            return false;
        }

        String lowerFieldName = fieldName.toLowerCase();
        return config.getFieldsToMask().stream()
                .anyMatch(field -> lowerFieldName.contains(field.toLowerCase()));
    }

    private boolean isSensitiveValue(String value) {
        if (value == null || value.trim().isEmpty()) {
            return false;
        }

        return EMAIL_PATTERN.matcher(value).matches() ||
                PHONE_PATTERN.matcher(value.replaceAll("[\\s()-]", "")).matches() ||
                SSN_PATTERN.matcher(value).matches();
    }

    @Override
    public String maskValue(String value, String fieldName) {
        if (value == null || value.trim().isEmpty()) {
            return value;
        }

        return switch (config.getStrategy()) {
            case PARTIAL -> maskPartial(value, fieldName);
            case FULL -> "***";
            case HASH -> maskWithHash(value);
        };
    }

    private String maskPartial(String value, String fieldName) {
        if (value.length() <= 2) {
            return "***";
        }

        // Special handling for email addresses
        if (EMAIL_PATTERN.matcher(value).matches()) {
            String[] parts = value.split("@");
            String localPart = parts[0];
            String domainPart = parts[1];

            String maskedLocal = localPart.length() > 2
                    ? localPart.charAt(0) + "***"
                    : "***";

            String maskedDomain = domainPart.length() > 4
                    ? domainPart.charAt(0) + "***" + domainPart.substring(domainPart.lastIndexOf('.'))
                    : "***.com";

            return maskedLocal + "@" + maskedDomain;
        }

        // Special handling for phone numbers
        if (PHONE_PATTERN.matcher(value.replaceAll("[\\s()-]", "")).matches()) {
            return value.substring(0, Math.min(3, value.length())) + "***" +
                    (value.length() > 6 ? value.substring(value.length() - 2) : "");
        }

        // Default partial masking
        if (value.length() <= 4) {
            return value.charAt(0) + "***";
        } else {
            return value.charAt(0) + "***" + value.charAt(value.length() - 1);
        }
    }

    private String maskWithHash(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();

            for (int i = 0; i < Math.min(8, hash.length); i++) {
                String hex = Integer.toHexString(0xff & hash[i]);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }

            return "HASH_" + hexString.toString().toUpperCase();
        } catch (NoSuchAlgorithmException e) {
            monitor.warning("Failed to create hash, falling back to full masking", e);
            return "***";
        }
    }

    @Override
    public String maskSensitiveData(String fieldName, String value) {
        if (shouldMaskField(fieldName) || isSensitiveValue(value)) {
            String maskedValue = maskValue(value, fieldName);

            if (config.isAuditEnabled()) {
                monitor.debug("Masked sensitive field: " + fieldName);
            }

            return maskedValue;
        }
        return value;
    }
}
