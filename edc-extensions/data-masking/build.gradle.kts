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

plugins {
    `java-library`
    `maven-publish`
}

dependencies {
    implementation(project(":spi:core-spi"))
    implementation(project(":core:core-utils"))
    
    // Event and monitoring for audit logging
    implementation(libs.edc.spi.core)
    
    // Control plane for Asset domain objects
    implementation(libs.edc.spi.controlplane)
    
    // Transform and JSON-LD dependencies
    implementation(libs.edc.spi.transform)
    implementation(libs.edc.spi.jsonld)
    implementation(libs.edc.lib.transform)
    
    // JSON processing for data transformation
    implementation(libs.jakartaJson)
    
    // Test dependencies
    testImplementation(libs.edc.junit)
}
