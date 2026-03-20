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

package org.eclipse.tractusx.edc.did.document.service;

import com.fasterxml.jackson.databind.ObjectMapper;
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

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.contains;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(DependencyInjectionExtension.class)
class DidDocumentServiceDivClientExtensionTest {

    private static final String DIV_URL = "https://div.example.com/api/v1";
    private static final String OWN_DID = "did:web:example.com:provider";

    private final Monitor monitor = mock(Monitor.class);
    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final DivOauth2Client divOauth2Client = mock(DivOauth2Client.class);
    private final TypeManager typeManager = mock(TypeManager.class);

    @BeforeEach
    void setup(ServiceExtensionContext context) {
        when(typeManager.getMapper()).thenReturn(new ObjectMapper());
        context.registerService(Monitor.class, monitor);
        context.registerService(EdcHttpClient.class, httpClient);
        context.registerService(DivOauth2Client.class, divOauth2Client);
        context.registerService(TypeManager.class, typeManager);
    }

    @Test
    void shouldRegisterClient_whenClientTypeIsDiv(ServiceExtensionContext context, ObjectFactory factory) {
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(allSettings()));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        var registeredClient = context.getService(DidDocumentServiceClient.class);
        assertThat(registeredClient).isInstanceOf(DidDocumentServiceDivClient.class);
    }

    @Test
    void shouldNotRegister_whenClientTypeIsIdentityhub(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.put("tx.edc.did.service.client.type", "identityhub");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("is not set to 'div'"));
    }

    @Test
    void shouldNotRegister_whenClientTypeIsMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("tx.edc.did.service.client.type");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(monitor).info(contains("is not set to 'div'"));
    }

    @Test
    void shouldNotRegister_whenDivUrlMissing(ServiceExtensionContext context, ObjectFactory factory) {
        var settings = allSettings();
        settings.remove("tx.edc.iam.sts.div.url");
        when(context.getConfig()).thenReturn(ConfigFactory.fromMap(settings));

        var extension = factory.constructInstance(DidDocumentServiceDivClientExtension.class);
        extension.initialize(context);

        verify(monitor).warning(contains("DIV URL not configured"));
    }

    private HashMap<String, String> allSettings() {
        return new HashMap<>(Map.of(
                "tx.edc.did.service.client.type", "div",
                "tx.edc.iam.sts.div.url", DIV_URL,
                "edc.participant.id", OWN_DID
        ));
    }
}
