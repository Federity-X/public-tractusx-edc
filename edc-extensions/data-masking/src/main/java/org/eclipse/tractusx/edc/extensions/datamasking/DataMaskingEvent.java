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

import org.eclipse.edc.spi.event.Event;

/**
 * Event fired when data masking occurs.
 */
public class DataMaskingEvent extends Event {
    private final String fieldName;
    private final String maskingStrategy;
    private final long timestamp;

    public DataMaskingEvent(String fieldName, String maskingStrategy) {
        this.fieldName = fieldName;
        this.maskingStrategy = maskingStrategy;
        this.timestamp = System.currentTimeMillis();
    }

    public String getFieldName() {
        return fieldName;
    }

    public String getMaskingStrategy() {
        return maskingStrategy;
    }

    public long getTimestamp() {
        return timestamp;
    }

    @Override
    public String name() {
        return "DataMaskingEvent";
    }
}
