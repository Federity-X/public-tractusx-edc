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
import java.net.URI;
import java.net.URISyntaxException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.List;
import java.util.function.Function;

import static org.eclipse.edc.http.spi.FallbackFactories.retryWhenStatusIsNotIn;

/**
 * Implementation of {@link DidDocumentServiceClient} that interacts with the IdentityHub
 * Identity Admin API to manage service entries in a DID Document.
 * <p>
 * Uses DELETE+POST (instead of PATCH) to handle both first-time registration and update
 * scenarios idempotently.
 */
public class DidDocumentServiceIdentityHubClient implements DidDocumentServiceClient {

    private static final String API_PATH_VERSION = "v1alpha";
    private static final String API_PATH_PARTICIPANTS = "participants";
    private static final String API_PATH_DIDS = "dids";
    private static final String API_PATH_ENDPOINTS = "endpoints";
    private static final MediaType JSON = MediaType.parse("application/json");

    private final EdcHttpClient httpClient;
    private final ObjectMapper mapper;
    private final String identityApiUrl;
    private final String apiKey;
    private final Monitor monitor;
    private final String encodedContextId;
    private final String encodedDid;

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
        this.apiKey = apiKey;
        this.monitor = monitor.withPrefix(getClass().getSimpleName());
        this.encodedContextId = Base64.getUrlEncoder().withoutPadding().encodeToString(participantContextId.getBytes(StandardCharsets.UTF_8));
        this.encodedDid = Base64.getUrlEncoder().withoutPadding().encodeToString(ownDid.getBytes(StandardCharsets.UTF_8));
    }

    @Override
    public ServiceResult<Void> update(Service service) {
        return validateService(service)
                .compose(v -> deleteServiceEntry(service.getId(), false))
                .compose(v -> createServiceEntry(service))
                .onSuccess(v -> monitor.info("Updated service entry %s in DID Document".formatted(asString(service))))
                .onFailure(f -> monitor.warning("Failed to update service entry %s with failure %s".formatted(asString(service), f.getFailureDetail())));
    }

    @Override
    public ServiceResult<Void> deleteById(String id) {
        return validateServiceId(id)
                .compose(v -> deleteServiceEntry(id, true))
                .onSuccess(v -> monitor.info("Deleted service entry %s".formatted(id)))
                .onFailure(f -> monitor.severe("Failed to delete service entry %s: %s".formatted(id, f.getFailureDetail())));
    }

    private ServiceResult<Void> validateService(Service service) {
        if (isBlank(service.getServiceEndpoint()) || isBlank(service.getType())) {
            return ServiceResult.unexpected("Validation Failure: Service id, type and serviceEndpoint must be provided and non-blank");
        }
        return validateServiceId(service.getId());
    }

    private ServiceResult<Void> validateServiceId(String serviceId) {
        if (isBlank(serviceId)) {
            return ServiceResult.unexpected("Validation Failure: Service ID must be provided and non-blank");
        }
        try {
            new URI(serviceId);
        } catch (URISyntaxException ex) {
            return ServiceResult.unexpected("Validation Failure: Service ID must be a valid URI: %s".formatted(serviceId));
        }
        return ServiceResult.success();
    }

    private ServiceResult<Void> createServiceEntry(Service service) {
        try {
            var body = mapper.writeValueAsString(service);
            var url = endpointsUrl()
                    .addQueryParameter("autoPublish", "true")
                    .build();
            var request = new Request.Builder()
                    .url(url)
                    .post(RequestBody.create(body, JSON))
                    .addHeader("x-api-key", apiKey)
                    .build();
            var result = httpClient.execute(request, List.of(retryWhenStatusIsNotIn(200, 201, 204, 409)), createResponseMapper());
            return result.succeeded() ? ServiceResult.success() : ServiceResult.unexpected(result.getFailureDetail());
        } catch (JsonProcessingException e) {
            return ServiceResult.unexpected("Failed to serialize service: %s".formatted(e.getMessage()));
        }
    }

    private ServiceResult<Void> deleteServiceEntry(String serviceId, boolean autoPublish) {
        var url = endpointsUrl()
                .addQueryParameter("serviceId", serviceId)
                .addQueryParameter("autoPublish", String.valueOf(autoPublish))
                .build();
        var request = new Request.Builder()
                .url(url)
                .delete()
                .addHeader("x-api-key", apiKey)
                .build();
        var result = httpClient.execute(request, List.of(retryWhenStatusIsNotIn(200, 204, 400)), deleteResponseMapper());
        return result.succeeded() ? ServiceResult.success() : ServiceResult.unexpected(result.getFailureDetail());
    }

    private HttpUrl.Builder endpointsUrl() {
        return HttpUrl.parse(identityApiUrl).newBuilder()
                .addPathSegment(API_PATH_VERSION)
                .addPathSegment(API_PATH_PARTICIPANTS)
                .addPathSegment(encodedContextId)
                .addPathSegment(API_PATH_DIDS)
                .addPathSegment(encodedDid)
                .addPathSegment(API_PATH_ENDPOINTS);
    }

    private Function<Response, Result<String>> createResponseMapper() {
        return response -> {
            var code = response.code();
            if (code == 200 || code == 201 || code == 204) {
                return Result.success(readBody(response));
            }
            if (code == 409) {
                // Service already exists — tolerated for idempotency
                return Result.success(readBody(response));
            }
            return Result.failure("Create service endpoint failed with status %d: %s".formatted(code, readBody(response)));
        };
    }

    private Function<Response, Result<String>> deleteResponseMapper() {
        return response -> {
            var code = response.code();
            if (code == 200 || code == 204) {
                return Result.success(readBody(response));
            }
            if (code == 400) {
                // Service not in DID — tolerated for idempotency (first-time registration)
                return Result.success(readBody(response));
            }
            return Result.failure("Delete service endpoint failed with status %d: %s".formatted(code, readBody(response)));
        };
    }

    private String readBody(Response response) {
        try {
            var body = response.body();
            return body != null ? body.string() : "";
        } catch (IOException e) {
            monitor.warning("Failed to read response body", e);
            return "[unreadable body: %s]".formatted(e.getMessage());
        }
    }

    private String asString(Service service) {
        return "{id=%s, type=%s, serviceEndpoint=%s}".formatted(service.getId(), service.getType(), service.getServiceEndpoint());
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
