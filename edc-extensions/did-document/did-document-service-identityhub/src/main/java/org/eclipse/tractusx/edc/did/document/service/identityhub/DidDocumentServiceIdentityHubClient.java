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

import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.iam.did.spi.document.Service;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.ServiceResult;
import org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient;

import java.io.IOException;
import java.util.Base64;
import java.util.List;

/**
 * Implementation of {@link DidDocumentServiceClient} that interacts with an Eclipse Tractus-X
 * IdentityHub to manage service entries in a DID Document.
 * <p>
 * Unlike the DIM-based implementation, IdentityHub provides a simple REST API:
 * <ul>
 *   <li>POST to add a service endpoint (with {@code autoPublish=true})</li>
 *   <li>DELETE to remove a service endpoint by ID</li>
 * </ul>
 * <p>
 * The API path is:
 * {@code /v1alpha/participants/{participantB64}/dids/{didB64}/endpoints}
 */
public class DidDocumentServiceIdentityHubClient implements DidDocumentServiceClient {

    static final MediaType JSON = MediaType.parse("application/json");

    private final EdcHttpClient httpClient;
    private final String identityApiUrl;
    private final String participantId;
    private final String ownDid;
    private final String apiKey;
    private final Monitor monitor;

    public DidDocumentServiceIdentityHubClient(EdcHttpClient httpClient,
                                               String identityApiUrl,
                                               String participantId,
                                               String ownDid,
                                               String apiKey,
                                               Monitor monitor) {
        this.httpClient = httpClient;
        this.identityApiUrl = identityApiUrl;
        this.participantId = participantId;
        this.ownDid = ownDid;
        this.apiKey = apiKey;
        this.monitor = monitor.withPrefix(getClass().getSimpleName());
    }

    @Override
    public ServiceResult<Void> update(Service service) {
        // IdentityHub handles upsert: delete existing (ignore 404) then create
        return deleteServiceEntry(service.getId())
                .compose(v -> createServiceEntry(service))
                .onSuccess(v -> monitor.info("Updated service entry '%s' (type=%s) in DID Document via IdentityHub"
                        .formatted(service.getId(), service.getType())))
                .onFailure(f -> monitor.warning("Failed to update service entry '%s': %s"
                        .formatted(service.getId(), f.getFailureDetail())));
    }

    @Override
    public ServiceResult<Void> deleteById(String id) {
        return deleteServiceEntry(id)
                .onSuccess(v -> monitor.info("Deleted service entry '%s' from DID Document via IdentityHub".formatted(id)))
                .onFailure(f -> monitor.severe("Failed to delete service entry '%s': %s".formatted(id, f.getFailureDetail())));
    }

    private ServiceResult<Void> createServiceEntry(Service service) {
        var json = "{\"id\":\"%s\",\"type\":\"%s\",\"serviceEndpoint\":\"%s\"}"
                .formatted(service.getId(), service.getType(), service.getServiceEndpoint());

        var request = new Request.Builder()
                .url(endpointsUrl() + "?autoPublish=true")
                .post(RequestBody.create(json, JSON))
                .addHeader("x-api-key", apiKey)
                .addHeader("Content-Type", "application/json")
                .build();

        return executeRequest(request, "create", 409);
    }

    private ServiceResult<Void> deleteServiceEntry(String serviceId) {
        var request = new Request.Builder()
                .url(endpointsUrl() + "/" + serviceId + "?autoPublish=true")
                .delete()
                .addHeader("x-api-key", apiKey)
                .build();

        return executeRequest(request, "delete", 404);
    }

    /**
     * Constructs the base URL for the IdentityHub endpoints API.
     * Path: {@code {identityApiUrl}/v1alpha/participants/{participantB64}/dids/{didB64}/endpoints}
     */
    private String endpointsUrl() {
        var participantB64 = base64Encode(participantId);
        var didB64 = base64Encode(ownDid);
        return "%s/v1alpha/participants/%s/dids/%s/endpoints".formatted(identityApiUrl, participantB64, didB64);
    }

    /**
     * Execute an HTTP request against the IdentityHub identity API.
     *
     * @param request         the OkHttp request
     * @param operation       label for logging
     * @param toleratedStatus additional status code to treat as success (e.g. 404 for delete, 409 for create)
     */
    private ServiceResult<Void> executeRequest(Request request, String operation, int toleratedStatus) {
        try (var response = httpClient.execute(request, List.of())) {
            if (response.isSuccessful()) {
                return ServiceResult.success();
            }
            if (response.code() == toleratedStatus) {
                monitor.debug("%s returned %d — treating as success (idempotent)".formatted(operation, toleratedStatus));
                return ServiceResult.success();
            }
            return handleResponse(response, operation);
        } catch (IOException e) {
            return ServiceResult.unexpected("IdentityHub %s request failed: %s".formatted(operation, e.getMessage()));
        }
    }

    ServiceResult<Void> handleResponse(Response response, String operation) {
        if (response.isSuccessful()) {
            return ServiceResult.success();
        }
        var body = "";
        try {
            if (response.body() != null) {
                body = response.body().string();
            }
        } catch (IOException e) {
            monitor.warning("Failed to read response body for %s".formatted(operation), e);
        }
        return ServiceResult.unexpected("IdentityHub %s failed with status %d: %s"
                .formatted(operation, response.code(), body));
    }

    static String base64Encode(String value) {
        return Base64.getEncoder().encodeToString(value.getBytes());
    }
}
