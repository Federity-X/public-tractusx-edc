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

import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.runtime.metamodel.annotation.Inject;
import org.eclipse.edc.runtime.metamodel.annotation.Provides;
import org.eclipse.edc.runtime.metamodel.annotation.Setting;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.system.ServiceExtension;
import org.eclipse.edc.spi.system.ServiceExtensionContext;
import org.eclipse.edc.spi.types.TypeManager;
import org.eclipse.tractusx.edc.iam.dcp.sts.div.oauth.DivOauth2Client;
import org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient;

import java.net.URI;

import static org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient.TX_EDC_DID_SERVICE_CLIENT_TYPE;

// Both DIV and IdentityHub extensions declare @Provides(DidDocumentServiceClient.class).
// Only the extension matching the configured clientType will actually register a client.
@Provides(DidDocumentServiceClient.class)
public class DidDocumentServiceDivClientExtension implements ServiceExtension {

    private static final String CLIENT_TYPE_DIV = "div";
    private static final String CLIENT_TYPE_IDENTITYHUB = "identityhub";

    @Inject
    private EdcHttpClient httpClient;

    @Inject(required = false)
    private DivOauth2Client divOauth2Client;

    @Inject
    private TypeManager typeManager;

    @Inject
    private Monitor monitor;

    @Setting(key = TX_EDC_DID_SERVICE_CLIENT_TYPE, description = "DID document service client type: 'div' or 'identityhub'", required = false)
    private String clientType;

    @Setting(key = "tx.edc.iam.sts.div.url", description = "STS Div endpoint", required = false)
    private String divUrl;

    @Setting(key = "edc.participant.id", description = "EDC Participant Id")
    private String ownDid;

    @Override
    public void initialize(ServiceExtensionContext context) {

        if (clientType == null || clientType.isBlank()) {
            monitor.info("DidDocumentServiceDIVClient: client type not configured, skipping registration");
            return;
        }

        if (!CLIENT_TYPE_DIV.equalsIgnoreCase(clientType)) {
            if (!CLIENT_TYPE_IDENTITYHUB.equalsIgnoreCase(clientType)) {
                monitor.warning("Unknown client type '%s' — valid values: 'div', 'identityhub'".formatted(clientType));
            }
            return;
        }

        if (divUrl == null || divUrl.isBlank() || divOauth2Client == null) {
            monitor.warning("DidDocumentServiceDIVClient: client type is 'div' but DIV URL not configured or DivOauth2Client is missing");
            return;
        }

        var client = new DidDocumentServiceDivClient(
                httpClient,
                divOauth2Client,
                typeManager.getMapper(),
                getHostWithScheme(divUrl),
                ownDid,
                monitor);
        context.registerService(DidDocumentServiceClient.class, client);
    }

    private String getHostWithScheme(String url) {
        var uri = URI.create(url);
        return "%s://%s".formatted(uri.getScheme(), uri.getAuthority());
    }
}
