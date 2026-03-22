/********************************************************************************
 * Copyright (c) 2025 SAP SE
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

package org.eclipse.tractusx.edc.did.document.service.identityhub;

import org.eclipse.edc.boot.system.injection.ObjectFactory;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.junit.extensions.DependencyInjectionExtension;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.spi.system.configuration.ConfigFactory;
import org.eclipse.edc.spi.types.TypeManager;
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
class DidDocumentServiceIdentityHubClientExtensionTest {

    private final Monitor monitor = mock(Monitor.class);
    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final Vault vault = mock(Vault.class);
    private final TypeManager typeManager = mock(TypeManager.class);

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        context.registerService(Monitor.class, monitor);
        context.registerService(EdcHttpClient.class, httpClient);
        context.registerService(Vault.class, vault);
        context.registerService(TypeManager.class, typeManager);
        when(typeManager.getMapper()).thenReturn(new com.fasterxml.jackson.databind.ObjectMapper());
    }

    @Test
    void shouldRegisterClient_whenClientTypeIsIdentityhub(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));
        when(vault.resolveSecret("ih-api-key-alias")).thenReturn("secret-key");

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context).registerService(eq(DidDocumentServiceClient.class), any(DidDocumentServiceIdentityHubClient.class));
    }

    @Test
    void shouldNotRegister_whenClientTypeIsDiv(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.put("tx.edc.did.service.client.type", "div");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
    }

    @Test
    void shouldNotRegister_whenClientTypeIsMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("tx.edc.did.service.client.type");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
    }

    @Test
    void shouldNotRegister_whenClientTypeIsBlank(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.put("tx.edc.did.service.client.type", "");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
    }

    @Test
    void shouldNotRegister_whenIdentityApiUrlMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("tx.edc.ih.identity.api.url");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("Identity API URL not configured"));
    }

    @Test
    void shouldNotRegister_whenIdentityApiUrlIsInvalid(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.put("tx.edc.ih.identity.api.url", "not-a-valid-url");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("not a valid HTTP(S) URL"));
    }

    @Test
    void shouldNotRegister_whenParticipantContextIdMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("tx.edc.ih.participant.context.id");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("participant context ID not configured"));
    }

    @Test
    void shouldNotRegister_whenOwnDidMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("edc.participant.id");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
    }

    @Test
    void shouldNotRegister_whenApiKeyAliasMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.remove("tx.edc.ih.identity.api.key.alias");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("API key alias not configured"));
    }

    @Test
    void shouldNotRegister_whenVaultReturnsNull(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));
        when(vault.resolveSecret("ih-api-key-alias")).thenReturn(null);

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("Vault returned null"));
    }

    @Test
    void shouldWarnOnUnrecognizedClientType(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = fullConfig();
        settings.put("tx.edc.did.service.client.type", "foobar");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(context, never()).registerService(eq(DidDocumentServiceClient.class), any());
        verify(monitor).warning(contains("Unknown client type"));
    }

    private Map<String, String> fullConfig() {
        var settings = new HashMap<String, String>();
        settings.put("tx.edc.did.service.client.type", "identityhub");
        settings.put("tx.edc.ih.identity.api.url", "http://identityhub:15151/api/identity");
        settings.put("tx.edc.ih.identity.api.key.alias", "ih-api-key-alias");
        settings.put("tx.edc.ih.participant.context.id", "participant-ctx-1");
        settings.put("edc.participant.id", "did:web:example.com:connector1");
        return settings;
    }
}
