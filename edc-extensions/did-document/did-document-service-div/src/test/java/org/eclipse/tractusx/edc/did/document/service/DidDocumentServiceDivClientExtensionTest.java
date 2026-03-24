/********************************************************************************
 * Copyright (c) 2025 SAP SE
 * Copyright (c) 2026 Technovative Solutions
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

package org.eclipse.tractusx.edc.did.document.service;

import org.eclipse.edc.boot.system.injection.ObjectFactory;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.junit.extensions.DependencyInjectionExtension;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.spi.system.configuration.ConfigFactory;
import org.eclipse.edc.spi.types.TypeManager;
import org.eclipse.tractusx.edc.iam.dcp.sts.div.oauth.DivOauth2Client;
import org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;

import java.util.HashMap;
import java.util.Map;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(DependencyInjectionExtension.class)
class DidDocumentServiceDivClientExtensionTest {

    private final Monitor monitor = mock(Monitor.class);
    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final TypeManager typeManager = mock(TypeManager.class);
    private final DivOauth2Client divOauth2Client = mock(DivOauth2Client.class);

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        context.registerService(Monitor.class, monitor);
        context.registerService(EdcHttpClient.class, httpClient);
        context.registerService(TypeManager.class, typeManager);
        context.registerService(DivOauth2Client.class, divOauth2Client);
        when(typeManager.getMapper()).thenReturn(new com.fasterxml.jackson.databind.ObjectMapper());
    }

    @Test
    void shouldRegisterClient_whenClientTypeIsDiv(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(context).registerService(eq(DidDocumentServiceClient.class), any(DidDocumentServiceDivClient.class));
    }

    @Test
    void shouldNotRegister_whenClientTypeIsIdentityhub(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.put("tx.edc.did.service.client.type", "identityhub");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
    }

    @Test
    void shouldNotRegister_whenClientTypeIsMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("tx.edc.did.service.client.type");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
    }

    @Test
    void shouldNotRegister_whenDivUrlMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("tx.edc.iam.sts.div.url");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("DIV URL not configured"));
    }

    @Test
    void shouldWarnOnUnrecognizedClientType(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.put("tx.edc.did.service.client.type", "unknown-type");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("Unknown client type"));
    }

    private Map<String, String> fullConfig() {
        var settings = new HashMap<String, String>();
        settings.put("tx.edc.did.service.client.type", "div");
        settings.put("tx.edc.iam.sts.div.url", "https://div.example.com/api");
        settings.put("edc.participant.id", "did:web:example.com:connector1");
        return settings;
    }
}
