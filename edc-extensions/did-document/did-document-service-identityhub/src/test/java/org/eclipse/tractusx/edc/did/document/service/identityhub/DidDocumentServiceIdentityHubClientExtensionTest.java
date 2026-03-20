/********************************************************************************
 * Copyright (c) 2025 Contributors to the Eclipse Foundation
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

package org.eclipse.tractusx.edc.did.document.service.identityhub;

import com.fasterxml.jackson.databind.ObjectMapper;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(DependencyInjectionExtension.class)
class DidDocumentServiceIdentityHubClientExtensionTest {

    private static final String IH_API_URL = "https://ih.example.com:15151/api/identity";
    private static final String API_KEY_ALIAS = "ih-api-key";
    private static final String API_KEY_VALUE = "super-secret-key";
    private static final String PARTICIPANT_CONTEXT_ID = "provider";
    private static final String OWN_DID = "did:web:example.com:provider";

    private final Monitor monitor = mock(Monitor.class);
    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final Vault vault = mock(Vault.class);
    private final TypeManager typeManager = mock(TypeManager.class);

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        when(typeManager.getMapper()).thenReturn(new ObjectMapper());
        context.registerService(Monitor.class, monitor);
        context.registerService(EdcHttpClient.class, httpClient);
        context.registerService(Vault.class, vault);
        context.registerService(TypeManager.class, typeManager);
    }

    @Test
    void shouldRegisterClient_whenClientTypeIsIdentityhub(ServiceExtensionContext context, ObjectFactory factory) {
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(allSettings()));
        when(vault.resolveSecret(API_KEY_ALIAS)).thenReturn(API_KEY_VALUE);

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        var registeredClient = context.getService(DidDocumentServiceClient.class);
        assertThat(registeredClient).isInstanceOf(DidDocumentServiceIdentityHubClient.class);
        verify(monitor).info(contains("Registered IdentityHub-based DidDocumentServiceClient"));
    }

    @Test
    void shouldNotRegister_whenClientTypeIsNotIdentityhub(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.put("tx.edc.did.service.client.type", "div");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("is not set to 'identityhub'"));
    }

    @Test
    void shouldNotRegister_whenClientTypeIsMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("tx.edc.did.service.client.type");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("is not set to 'identityhub'"));
    }

    @Test
    void shouldNotRegister_whenIdentityApiUrlMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("tx.edc.ih.identity.api.url");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("tx.edc.ih.identity.api.url is not configured"));
    }

    @Test
    void shouldNotRegister_whenIdentityApiUrlIsInvalid(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.put("tx.edc.ih.identity.api.url", "not-a-valid-url");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).warning(contains("is not a valid HTTP(S) URL"));
    }

    @Test
    void shouldNotRegister_whenParticipantContextIdMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("tx.edc.ih.participant.context.id");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("tx.edc.ih.participant.context.id is not configured"));
    }

    @Test
    void shouldNotRegister_whenVaultAliasResolvesToNull(ServiceExtensionContext context, ObjectFactory factory) {
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(allSettings()));
        when(vault.resolveSecret(API_KEY_ALIAS)).thenReturn(null);

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).warning(contains("could not resolve API key from vault alias"));
    }

    @Test
    void shouldNotRegister_whenOwnDidMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("edc.iam.issuer.id");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("edc.iam.issuer.id is not configured"));
    }

    @Test
    void shouldNotRegister_whenApiKeyAliasMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("tx.edc.ih.identity.api.key.alias");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceIdentityHubClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("tx.edc.ih.identity.api.key.alias is not configured"));
    }

    private HashMap<String, String> allSettings() {
        return new HashMap<>(Map.of(
                "tx.edc.did.service.client.type", "identityhub",
                "tx.edc.ih.identity.api.url", IH_API_URL,
                "tx.edc.ih.identity.api.key.alias", API_KEY_ALIAS,
                "tx.edc.ih.participant.context.id", PARTICIPANT_CONTEXT_ID,
                "edc.iam.issuer.id", OWN_DID
        ));
    }
}
