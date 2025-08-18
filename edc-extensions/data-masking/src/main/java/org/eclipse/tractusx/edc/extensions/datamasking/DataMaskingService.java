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

import java.util.Map;

/**
 * Service interface for data masking operations.
 */
public interface DataMaskingService {

    /**
     * Masks sensitive data in the provided data map.
     *
     * @param data the data to mask
     * @return the masked data
     */
    Map<String, Object> maskData(Map<String, Object> data);

    /**
     * Masks sensitive data in JSON string format.
     *
     * @param jsonData the JSON data to mask
     * @return the masked JSON data
     */
    String maskJsonData(String jsonData);

    /**
     * Checks if a field should be masked based on configuration.
     *
     * @param fieldName the field name to check
     * @return true if the field should be masked, false otherwise
     */
    boolean shouldMaskField(String fieldName);

    /**
     * Masks a single value based on the configured strategy.
     *
     * @param value     the value to mask
     * @param fieldName the name of the field (for context)
     * @return the masked value
     */
    String maskValue(String value, String fieldName);

    /**
     * Masks sensitive data for a specific field.
     *
     * @param fieldName the name of the field
     * @param value     the value to potentially mask
     * @return the masked value if field is sensitive, original value otherwise
     */
    String maskSensitiveData(String fieldName, String value);
}
