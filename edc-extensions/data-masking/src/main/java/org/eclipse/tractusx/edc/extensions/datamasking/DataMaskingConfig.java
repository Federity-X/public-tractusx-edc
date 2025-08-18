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

import java.util.Set;

/**
 * Configuration for data masking operations.
 */
public class DataMaskingConfig {
    private final MaskingStrategy strategy;
    private final Set<String> fieldsToMask;
    private final boolean auditEnabled;

    private DataMaskingConfig(Builder builder) {
        this.strategy = builder.strategy;
        this.fieldsToMask = Set.of(builder.fieldsToMask);
        this.auditEnabled = builder.auditEnabled;
    }

    public MaskingStrategy getStrategy() {
        return strategy;
    }

    public Set<String> getFieldsToMask() {
        return fieldsToMask;
    }

    public boolean isAuditEnabled() {
        return auditEnabled;
    }

    public static Builder builder() {
        return new Builder();
    }

    public static class Builder {
        private MaskingStrategy strategy = MaskingStrategy.PARTIAL;
        private String[] fieldsToMask = {};
        private boolean auditEnabled = true;

        public Builder strategy(MaskingStrategy strategy) {
            this.strategy = strategy;
            return this;
        }

        public Builder fieldsToMask(String[] fieldsToMask) {
            this.fieldsToMask = fieldsToMask;
            return this;
        }

        public Builder auditEnabled(boolean auditEnabled) {
            this.auditEnabled = auditEnabled;
            return this;
        }

        public DataMaskingConfig build() {
            return new DataMaskingConfig(this);
        }
    }
}
