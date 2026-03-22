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

import static org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient.TX_EDC_DID_SERVICE_CLIENT_TYPE;

// Both DIV and IdentityHub extensions declare @Provides(DidDocumentServiceClient.class).
// Only the extension matching the configured clientType will actually register a client.
@Provides(DidDocumentServiceClient.class)
public class DidDocumentServiceIdentityHubClientExtension implements ServiceExtension {

    private static final String CLIENT_TYPE_DIV = "div";
    private static final String CLIENT_TYPE_IDENTITYHUB = "identityhub";

    @Inject
    private EdcHttpClient httpClient;

    @Inject
    private Vault vault;

    @Inject
    private TypeManager typeManager;

    @Inject
    private Monitor monitor;

    @Setting(key = TX_EDC_DID_SERVICE_CLIENT_TYPE, description = "DID document service client type: 'div' or 'identityhub'", required = false)
    private String clientType;

    @Setting(key = "tx.edc.ih.identity.api.url", description = "IdentityHub Identity Admin API base URL", required = false)
    private String identityApiUrl;

    @Setting(key = "tx.edc.ih.identity.api.key.alias", description = "Vault alias for the X-Api-Key secret", required = false)
    private String apiKeyAlias;

    @Setting(key = "tx.edc.ih.participant.context.id", description = "IdentityHub participant context ID", required = false)
    private String participantContextId;

    @Setting(key = "edc.participant.id", description = "EDC Participant Id", required = false)
    private String ownDid;

    @Override
    public void initialize(ServiceExtensionContext context) {

        if (clientType == null || clientType.isBlank()) {
            monitor.info("DidDocumentServiceIdentityHubClient: client type not configured, skipping registration");
            return;
        }

        if (!CLIENT_TYPE_IDENTITYHUB.equalsIgnoreCase(clientType)) {
            if (!CLIENT_TYPE_DIV.equalsIgnoreCase(clientType)) {
                monitor.warning("Unknown client type '%s' — valid values: 'div', 'identityhub'".formatted(clientType));
            }
            return;
        }

        if (identityApiUrl == null || identityApiUrl.isBlank()) {
            monitor.warning("DidDocumentServiceIdentityHubClient: Identity API URL not configured");
            return;
        }

        if (HttpUrl.parse(identityApiUrl) == null) {
            monitor.warning("DidDocumentServiceIdentityHubClient: Identity API URL is not a valid HTTP(S) URL: %s".formatted(identityApiUrl));
            return;
        }

        if (participantContextId == null || participantContextId.isBlank()) {
            monitor.warning("DidDocumentServiceIdentityHubClient: participant context ID not configured");
            return;
        }

        if (ownDid == null || ownDid.isBlank()) {
            monitor.warning("DidDocumentServiceIdentityHubClient: own DID (edc.participant.id) not configured");
            return;
        }

        if (apiKeyAlias == null || apiKeyAlias.isBlank()) {
            monitor.warning("DidDocumentServiceIdentityHubClient: API key alias not configured");
            return;
        }

        var apiKey = vault.resolveSecret(apiKeyAlias);
        if (apiKey == null) {
            monitor.warning("DidDocumentServiceIdentityHubClient: Vault returned null for alias '%s'".formatted(apiKeyAlias));
            return;
        }

        var client = new DidDocumentServiceIdentityHubClient(
                httpClient,
                typeManager.getMapper(),
                identityApiUrl,
                participantContextId,
                ownDid,
                apiKey,
                monitor);
        context.registerService(DidDocumentServiceClient.class, client);
    }
}
