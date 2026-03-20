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

import okhttp3.HttpUrl;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provides;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.security.Vault;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.spi.types.TypeManager;
import org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient;

/**
 * Extension that provides a {@link DidDocumentServiceClient} backed by the IdentityHub Identity Admin API.
 * <p>
 * This extension activates when {@code tx.edc.did.service.client.type} is set to {@code "identityhub"}
 * and all required IdentityHub configuration properties are present.
 * <p>
 * The API key is resolved from the vault using the alias specified in {@code tx.edc.ih.identity.api.key.alias}.
 */
// Note: Both this and DidDocumentServiceDivClientExtension declare @Provides(DidDocumentServiceClient.class).
// Only one extension will call registerService() at runtime, selected by tx.edc.did.service.client.type.
@Provides(DidDocumentServiceClient.class)
public class DidDocumentServiceIdentityHubClientExtension implements ServiceExtension {

    public static final String CLIENT_TYPE_IDENTITYHUB = "identityhub";
    public static final String TX_EDC_IH_IDENTITY_API_URL = "tx.edc.ih.identity.api.url";
    public static final String TX_EDC_IH_IDENTITY_API_KEY_ALIAS = "tx.edc.ih.identity.api.key.alias";
    public static final String TX_EDC_IH_PARTICIPANT_CONTEXT_ID = "tx.edc.ih.participant.context.id";

    @Inject
    private EdcHttpClient httpClient;

    @Inject
    private TypeManager typeManager;

    @Inject
    private Vault vault;

    @Inject
    private Monitor monitor;

    @Setting(key = TX_EDC_IH_IDENTITY_API_URL, description = "IdentityHub Identity Admin API base URL", required = false)
    private String identityApiUrl;

    @Setting(key = TX_EDC_IH_IDENTITY_API_KEY_ALIAS, description = "Vault alias for the IdentityHub Identity API key (x-api-key header)", required = false)
    private String apiKeyAlias;

    @Setting(key = TX_EDC_IH_PARTICIPANT_CONTEXT_ID, description = "IdentityHub participant context ID", required = false)
    private String participantContextId;

    @Setting(key = "edc.iam.issuer.id", description = "DID of this connector", required = false)
    private String ownDid;

    @Setting(key = DidDocumentServiceClient.TX_EDC_DID_SERVICE_CLIENT_TYPE, description = "Type of DidDocumentServiceClient to activate (e.g. 'div', 'identityhub')", required = false)
    private String clientType;

    @Override
    public void initialize(ServiceExtensionContext context) {
        if (!CLIENT_TYPE_IDENTITYHUB.equalsIgnoreCase(clientType)) {
            monitor.info("IdentityHub DidDocumentServiceClient will not be registered: %s is not set to '%s'".formatted(DidDocumentServiceClient.TX_EDC_DID_SERVICE_CLIENT_TYPE, CLIENT_TYPE_IDENTITYHUB));
            return;
        }

        if (identityApiUrl == null || identityApiUrl.isBlank()) {
            monitor.info("IdentityHub DidDocumentServiceClient will not be registered: %s is not configured".formatted(TX_EDC_IH_IDENTITY_API_URL));
            return;
        }

        if (HttpUrl.parse(identityApiUrl) == null) {
            monitor.warning("IdentityHub DidDocumentServiceClient will not be registered: %s is not a valid HTTP(S) URL: '%s'".formatted(TX_EDC_IH_IDENTITY_API_URL, identityApiUrl));
            return;
        }

        if (participantContextId == null || participantContextId.isBlank()) {
            monitor.info("IdentityHub DidDocumentServiceClient will not be registered: %s is not configured".formatted(TX_EDC_IH_PARTICIPANT_CONTEXT_ID));
            return;
        }

        if (ownDid == null || ownDid.isBlank()) {
            monitor.info("IdentityHub DidDocumentServiceClient will not be registered: edc.iam.issuer.id is not configured");
            return;
        }

        if (apiKeyAlias == null || apiKeyAlias.isBlank()) {
            monitor.info("IdentityHub DidDocumentServiceClient will not be registered: %s is not configured".formatted(TX_EDC_IH_IDENTITY_API_KEY_ALIAS));
            return;
        }

        var apiKey = vault.resolveSecret(apiKeyAlias);
        if (apiKey == null) {
            monitor.warning("IdentityHub DidDocumentServiceClient will not be registered: could not resolve API key from vault alias '%s'".formatted(apiKeyAlias));
            return;
        }

        var client = new DidDocumentServiceIdentityHubClient(
                httpClient, typeManager.getMapper(), identityApiUrl, participantContextId, ownDid, apiKey, monitor);
        context.registerService(DidDocumentServiceClient.class, client);
        monitor.info("Registered IdentityHub-based DidDocumentServiceClient (API: %s)".formatted(identityApiUrl));
    }
}
