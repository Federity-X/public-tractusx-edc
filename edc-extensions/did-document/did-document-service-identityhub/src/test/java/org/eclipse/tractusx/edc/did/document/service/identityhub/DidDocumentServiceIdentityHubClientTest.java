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
import okhttp3.Protocol;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.iam.did.spi.document.Service;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.function.Function;

import static org.assertj.core.api.Assertions.assertThat;
import static org.eclipse.edc.junit.assertions.AbstractResultAssert.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DidDocumentServiceIdentityHubClientTest {

    private static final String IH_API_URL = "https://ih.example.com:15151/api/identity";
    private static final String PARTICIPANT_CONTEXT_ID = "provider";
    private static final String OWN_DID = "did:web:example.com:provider";
    private static final String API_KEY = "test-api-key-secret";
    private static final String SERVICE_ID = "dsp-endpoint";
    private static final String SERVICE_TYPE = "DataService";
    private static final String SERVICE_ENDPOINT = "https://edc.example.com/.well-known/dspace-version";

    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final ObjectMapper mapper = new ObjectMapper();
    private final Monitor monitor = mock(Monitor.class);
    private DidDocumentServiceIdentityHubClient client;
    private String expectedEndpointsUrl;

    @BeforeEach
    void setUp() {
        when(monitor.withPrefix(any())).thenReturn(monitor);
        client = new DidDocumentServiceIdentityHubClient(
                httpClient, mapper, IH_API_URL, PARTICIPANT_CONTEXT_ID, OWN_DID, API_KEY, monitor);

        var contextIdB64 = Base64.getUrlEncoder().withoutPadding().encodeToString(PARTICIPANT_CONTEXT_ID.getBytes(StandardCharsets.UTF_8));
        var didB64 = Base64.getUrlEncoder().withoutPadding().encodeToString(OWN_DID.getBytes(StandardCharsets.UTF_8));
        expectedEndpointsUrl = IH_API_URL + "/v1alpha/participants/" + contextIdB64 + "/dids/" + didB64 + "/endpoints";
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldDeleteThenCreate() {
        // Mock the 3-arg execute: invoke the handler with a mock response
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(204)); // delete → 204
                })
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(200)); // create → 200
                });

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();

        var captor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient, times(2)).execute(captor.capture(), anyList(), any(Function.class));

        var requests = captor.getAllValues();

        // First call: DELETE
        var deleteRequest = requests.get(0);
        assertThat(deleteRequest.method()).isEqualTo("DELETE");
        assertThat(deleteRequest.url().toString()).startsWith(expectedEndpointsUrl);
        assertThat(deleteRequest.url().queryParameter("serviceId")).isEqualTo(SERVICE_ID);
        assertThat(deleteRequest.url().queryParameter("autoPublish")).isEqualTo("true");
        assertThat(deleteRequest.header("X-Api-Key")).isEqualTo(API_KEY);

        // Second call: POST
        var createRequest = requests.get(1);
        assertThat(createRequest.method()).isEqualTo("POST");
        assertThat(createRequest.url().toString()).startsWith(expectedEndpointsUrl);
        assertThat(createRequest.url().queryParameter("autoPublish")).isEqualTo("true");
        assertThat(createRequest.header("X-Api-Key")).isEqualTo(API_KEY);
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldEncodeDidInBase64Url() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(204));
                })
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(200));
                });

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        client.update(service);

        var captor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient, times(2)).execute(captor.capture(), anyList(), any(Function.class));

        var url = captor.getAllValues().get(0).url().toString();
        var contextIdB64 = Base64.getUrlEncoder().withoutPadding().encodeToString(PARTICIPANT_CONTEXT_ID.getBytes(StandardCharsets.UTF_8));
        var didB64 = Base64.getUrlEncoder().withoutPadding().encodeToString(OWN_DID.getBytes(StandardCharsets.UTF_8));
        assertThat(url).contains("/participants/" + contextIdB64 + "/dids/" + didB64 + "/endpoints");
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldFailWhenCreateFails() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(204)); // delete ok
                })
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(500)); // create fails
                });

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldSucceedWhenCreateReturns409() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(204)); // delete
                })
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(409)); // create conflict → tolerated
                });

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();
    }

    @Test
    @SuppressWarnings("unchecked")
    void deleteById_shouldCallDeleteEndpoint() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(204));
                });

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isSucceeded();

        var captor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient).execute(captor.capture(), anyList(), any(Function.class));

        var request = captor.getValue();
        assertThat(request.method()).isEqualTo("DELETE");
        assertThat(request.url().queryParameter("serviceId")).isEqualTo(SERVICE_ID);
        assertThat(request.url().queryParameter("autoPublish")).isEqualTo("true");
        assertThat(request.header("X-Api-Key")).isEqualTo(API_KEY);
    }

    @Test
    @SuppressWarnings("unchecked")
    void deleteById_shouldSucceedWhenNotFound() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(404));
                });

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isSucceeded();
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldFailWhenHttpExecuteReturnsFailure() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenReturn(Result.failure("connection refused"));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldFailWhenDeleteReturnsServerError() {
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(500)); // delete fails
                });

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
        // create should never have been called — only 1 execute invocation
        verify(httpClient, times(1)).execute(any(Request.class), anyList(), any(Function.class));
    }

    @Test
    @SuppressWarnings("unchecked")
    void update_shouldFailWhenSerializationFails() throws Exception {
        var failingMapper = mock(ObjectMapper.class);
        when(failingMapper.writeValueAsString(any())).thenThrow(new JsonProcessingException("boom") {});
        when(monitor.withPrefix(any())).thenReturn(monitor);

        var failingClient = new DidDocumentServiceIdentityHubClient(
                httpClient, failingMapper, IH_API_URL, PARTICIPANT_CONTEXT_ID, OWN_DID, API_KEY, monitor);

        // delete succeeds
        when(httpClient.execute(any(Request.class), anyList(), any(Function.class)))
                .thenAnswer(inv -> {
                    Function<Response, Result<String>> handler = inv.getArgument(2);
                    return handler.apply(response(204));
                });

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = failingClient.update(service);

        assertThat(result).isFailed();
    }

    private Response response(int code) {
        return new Response.Builder()
                .request(new Request.Builder().url("https://localhost").build())
                .protocol(Protocol.HTTP_1_1)
                .code(code)
                .message("mock")
                .body(ResponseBody.create("", null))
                .build();
    }
}
