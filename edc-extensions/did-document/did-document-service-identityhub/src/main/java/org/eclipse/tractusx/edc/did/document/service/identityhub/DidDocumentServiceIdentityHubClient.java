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

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.iam.did.spi.document.Service;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;
import org.eclipse.edc.spi.result.ServiceResult;
import org.eclipse.tractusx.edc.spi.did.document.service.DidDocumentServiceClient;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.Objects;
import java.util.function.Function;

import static org.eclipse.edc.http.spi.FallbackFactories.retryWhenStatusIsNotIn;

/**
 * Implementation of {@link DidDocumentServiceClient} that calls the Tractus-X IdentityHub
 * Identity API to register or remove service entries in a participant's DID Document.
 * <p>
 * API contract (eclipse-edc/IdentityHub {@code DidManagementApiController}):
 * <pre>
 *   POST   /v1alpha/participants/{participantContextId}/dids/{base64did}/endpoints?autoPublish=true
 *   DELETE /v1alpha/participants/{participantContextId}/dids/{base64did}/endpoints?serviceId={id}&amp;autoPublish=true
 * </pre>
 * <p>
 * Authentication: {@code X-Api-Key} header (IdentityHub Identity API key, stored in Vault).
 * <p>
 * The {@code update} operation follows a delete-then-create pattern with idempotent error handling:
 * <ul>
 *     <li>404 on delete → tolerated (endpoint may not exist yet)</li>
 *     <li>409 on create → tolerated (endpoint may already exist)</li>
 * </ul>
 */
public class DidDocumentServiceIdentityHubClient implements DidDocumentServiceClient {

    static final MediaType JSON = MediaType.parse("application/json");
    private static final String PARTICIPANTS_PATH = "v1alpha/participants";

    private final EdcHttpClient httpClient;
    private final ObjectMapper mapper;
    private final String identityApiUrl;
    private final String participantContextId;
    private final String ownDid;
    private final String apiKey;
    private final Monitor monitor;

    public DidDocumentServiceIdentityHubClient(EdcHttpClient httpClient,
                                               ObjectMapper mapper,
                                               String identityApiUrl,
                                               String participantContextId,
                                               String ownDid,
                                               String apiKey,
                                               Monitor monitor) {
        this.httpClient = httpClient;
        this.mapper = mapper;
        this.identityApiUrl = identityApiUrl;
        this.participantContextId = participantContextId;
        this.ownDid = ownDid;
        this.apiKey = apiKey;
        this.monitor = monitor.withPrefix(getClass().getSimpleName());
    }

    @Override
    public ServiceResult<Void> update(Service service) {
        return deleteServiceEntry(service.getId())
                .compose(v -> createServiceEntry(service))
                .onSuccess(v -> monitor.info("Registered service entry '%s' in IdentityHub DID Document".formatted(service.getId())))
                .onFailure(f -> monitor.warning("Failed to register service entry '%s': %s".formatted(service.getId(), f.getFailureDetail())));
    }

    @Override
    public ServiceResult<Void> deleteById(String serviceId) {
        return deleteServiceEntry(serviceId)
                .onSuccess(v -> monitor.info("Deleted service entry '%s' from IdentityHub DID Document".formatted(serviceId)))
                .onFailure(f -> monitor.warning("Failed to delete service entry '%s': %s".formatted(serviceId, f.getFailureDetail())));
    }

    private ServiceResult<Void> deleteServiceEntry(String serviceId) {
        var url = buildEndpointsUrl()
                .addQueryParameter("serviceId", serviceId)
                .addQueryParameter("autoPublish", "true")
                .build()
                .toString();
        var request = new Request.Builder()
                .url(url)
                .delete()
                .addHeader("X-Api-Key", apiKey)
                .build();
        return ServiceResult.from(executeRequest(request, response -> handleDeleteResponse(response, serviceId))).mapEmpty();
    }

    private ServiceResult<Void> createServiceEntry(Service service) {
        var url = buildEndpointsUrl()
                .addQueryParameter("autoPublish", "true")
                .build()
                .toString();

        try {
            var body = RequestBody.create(mapper.writeValueAsString(service), JSON);
            var request = new Request.Builder()
                    .url(url)
                    .post(body)
                    .addHeader("X-Api-Key", apiKey)
                    .build();
            return ServiceResult.from(executeRequest(request, response -> handleCreateResponse(response, service.getId()))).mapEmpty();
        } catch (JsonProcessingException e) {
            return ServiceResult.unexpected("Failed to serialize service: " + e.getMessage());
        }
    }

    private Result<String> executeRequest(Request request,
                                          Function<Response, Result<String>> handler) {
        return httpClient.execute(request, List.of(retryWhenStatusIsNotIn(200, 201, 204, 401, 403, 404, 409)), handler);
    }

    private Result<String> handleDeleteResponse(Response response, String serviceId) {
        if (response.isSuccessful() || response.code() == 404) {
            return Result.success("ok");
        }
        return Result.failure("Delete endpoint '%s' failed: HTTP %d — %s"
                .formatted(serviceId, response.code(), readBody(response)));
    }

    private Result<String> handleCreateResponse(Response response, String serviceId) {
        if (response.isSuccessful() || response.code() == 409) {
            return Result.success("ok");
        }
        return Result.failure("Create endpoint '%s' failed: HTTP %d — %s"
                .formatted(serviceId, response.code(), readBody(response)));
    }

    private String readBody(Response response) {
        try {
            var body = response.body();
            return body != null ? body.string() : "";
        } catch (IOException e) {
            return "(could not read body: %s)".formatted(e.getMessage());
        }
    }

    private HttpUrl.Builder buildEndpointsUrl() {
        var contextIdB64 = base64UrlEncode(participantContextId);
        var didB64 = base64UrlEncode(ownDid);
        return Objects.requireNonNull(HttpUrl.parse(identityApiUrl)).newBuilder()
                .addPathSegments(PARTICIPANTS_PATH)
                .addPathSegment(contextIdB64)
                .addPathSegment("dids")
                .addPathSegment(didB64)
                .addPathSegment("endpoints");
    }

    private String base64UrlEncode(String value) {
        return Base64.getUrlEncoder().withoutPadding()
                .encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }
}
