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

package org.eclipse.tractusx.edc.did.document.service.identityhub;

import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provides;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient;

/**
 * Extension that registers a {@link DidDocumentServiceClient} backed by the
 * IdentityHub identity API, enabling DID Document self-registration for
 * deployments that use IdentityHub as their wallet (instead of SAP DIM).
 * <p>
 * This extension activates only when {@code tx.edc.ih.api.url} is configured.
 * If missing, it logs a message and skips registration, allowing the DIM-based
 * client to take over (or no client at all).
 */
@Provides(DidDocumentServiceClient.class)
public class DidDocumentServiceIdentityHubClientExtension implements ServiceExtension {

    public static final String TX_EDC_IH_API_URL = "tx.edc.ih.api.url";
    public static final String TX_EDC_IH_API_KEY = "tx.edc.ih.api.key";
    public static final String TX_EDC_IH_PARTICIPANT_CONTEXT_ID = "tx.edc.ih.participant.context.id";

    @Inject
    private EdcHttpClient httpClient;

    @Inject
    private Monitor monitor;

    @Setting(key = TX_EDC_IH_API_URL, description = "IdentityHub identity API base URL (e.g. http://provider-ih:15151/api/identity)", required = false)
    private String identityHubApiUrl;

    @Setting(key = TX_EDC_IH_API_KEY, description = "API key for IdentityHub identity API", required = false)
    private String identityHubApiKey;

    @Setting(key = TX_EDC_IH_PARTICIPANT_CONTEXT_ID, description = "IdentityHub participant context ID (short name, e.g. 'provider')", required = false)
    private String participantContextId;

    @Setting(key = "edc.iam.issuer.id", description = "The DID of this connector's participant")
    private String ownDid;

    @Override
    public void initialize(ServiceExtensionContext context) {
        if (identityHubApiUrl == null || identityHubApiUrl.isBlank()) {
            monitor.info("IdentityHub DID Document Service client will not be registered: %s is not configured".formatted(TX_EDC_IH_API_URL));
            return;
        }

        if (identityHubApiKey == null || identityHubApiKey.isBlank()) {
            monitor.warning("IdentityHub DID Document Service client will not be registered: %s is not configured".formatted(TX_EDC_IH_API_KEY));
            return;
        }

        if (participantContextId == null || participantContextId.isBlank()) {
            monitor.warning("IdentityHub DID Document Service client will not be registered: %s is not configured".formatted(TX_EDC_IH_PARTICIPANT_CONTEXT_ID));
            return;
        }

        var client = new DidDocumentServiceIdentityHubClient(
                httpClient,
                identityHubApiUrl,
                participantContextId,
                ownDid,
                identityHubApiKey,
                monitor);

        context.registerService(DidDocumentServiceClient.class, client);
        monitor.info("Registered IdentityHub-based DidDocumentServiceClient (API: %s, DID: %s)".formatted(identityHubApiUrl, ownDid));
    }
}
