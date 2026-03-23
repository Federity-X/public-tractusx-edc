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
import okhttp3.Request;
import org.eclipse.edc.http.spi.EdcHttpClient;
import org.eclipse.edc.iam.did.spi.document.Service;
import org.eclipse.edc.spi.monitor.Monitor;
import org.eclipse.edc.spi.result.Result;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.ArgumentCaptor;

import java.util.Base64;

import static org.assertj.core.api.Assertions.assertThat;
import static org.eclipse.edc.junit.assertions.AbstractResultAssert.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DidDocumentServiceIdentityHubClientTest {

    private static final String SERVICE_ID = "did:web:example.com:connector1#DataService";
    private static final String SERVICE_TYPE = "DataService";
    private static final String SERVICE_ENDPOINT = "https://edc.example.com/.well-known/dspace-version";
    private static final String IDENTITY_API_URL = "http://identityhub:15151/api/identity";
    private static final String PARTICIPANT_CONTEXT_ID = "participant-ctx-1";
    private static final String OWN_DID = "did:web:example.com:connector1";
    private static final String API_KEY = "test-api-key";

    private final EdcHttpClient httpClient = mock(EdcHttpClient.class);
    private final ObjectMapper mapper = new ObjectMapper();
    private final Monitor monitor = mock(Monitor.class);

    private DidDocumentServiceIdentityHubClient client;

    @BeforeEach
    void setUp() {
        when(monitor.withPrefix(anyString())).thenReturn(monitor);
        client = new DidDocumentServiceIdentityHubClient(httpClient, mapper, IDENTITY_API_URL, PARTICIPANT_CONTEXT_ID, OWN_DID, API_KEY, monitor);
    }

    @Test
    void update_shouldDeleteThenCreate() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success("")) // delete
                .thenReturn(Result.success("")); // create

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();

        var requestCaptor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient, times(2)).execute(requestCaptor.capture(), anyList(), any());

        var requests = requestCaptor.getAllValues();
        assertThat(requests.get(0).method()).isEqualTo("DELETE");
        assertThat(requests.get(1).method()).isEqualTo("POST");

        // Verify headers
        assertThat(requests.get(0).header("x-api-key")).isEqualTo(API_KEY);
        assertThat(requests.get(1).header("x-api-key")).isEqualTo(API_KEY);
    }

    @Test
    void update_shouldEncodePathParametersInBase64Url() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success(""))
                .thenReturn(Result.success(""));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        client.update(service);

        var requestCaptor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient, times(2)).execute(requestCaptor.capture(), anyList(), any());

        var url = requestCaptor.getAllValues().get(0).url().toString();
        var expectedContextId = Base64.getUrlEncoder().withoutPadding().encodeToString(PARTICIPANT_CONTEXT_ID.getBytes());
        var expectedDid = Base64.getUrlEncoder().withoutPadding().encodeToString(OWN_DID.getBytes());
        assertThat(url).contains(expectedContextId);
        assertThat(url).contains(expectedDid);
    }

    @Test
    void update_shouldFailWhenCreateReturns500() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success("")) // delete OK
                .thenReturn(Result.failure("Server error")); // create fails

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
    }

    @Test
    void update_shouldSucceedWhenCreateReturns409() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success("")) // delete
                .thenReturn(Result.success("")); // create (409 handled by response mapper → success)

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();
    }

    @Test
    void update_shouldFailWhenDeleteReturns500() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.failure("Server error on delete"));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
        // create should not have been called
        verify(httpClient, times(1)).execute(any(Request.class), anyList(), any());
    }

    @Test
    void update_shouldSucceedWhenDeleteReturns400() {
        // First-time registration: service not yet in DID, 400 tolerated on DELETE
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success("")) // delete (400 → success via response mapper)
                .thenReturn(Result.success("")); // create

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isSucceeded();
        verify(httpClient, times(2)).execute(any(Request.class), anyList(), any());
    }

    @Test
    void update_shouldFailWhenSerializationFails() throws JsonProcessingException {
        var brokenMapper = mock(ObjectMapper.class);
        when(brokenMapper.writeValueAsString(any())).thenThrow(new JsonProcessingException("test") {});

        var brokenClient = new DidDocumentServiceIdentityHubClient(httpClient, brokenMapper, IDENTITY_API_URL, PARTICIPANT_CONTEXT_ID, OWN_DID, API_KEY, monitor);

        // delete succeeds first
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success(""));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = brokenClient.update(service);

        assertThat(result).isFailed();
    }

    @Test
    void update_shouldFailWhenHttpClientFails() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.failure("Network error"));

        var service = new Service(SERVICE_ID, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"", "   "})
    void update_shouldValidateServiceId(String serviceId) {
        var service = new Service(serviceId, SERVICE_TYPE, SERVICE_ENDPOINT);
        var result = client.update(service);

        assertThat(result).isFailed();
        verify(httpClient, never()).execute(any(Request.class), anyList(), any());
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"", "   "})
    void update_shouldValidateServiceEndpoint(String endpoint) {
        var service = new Service(SERVICE_ID, SERVICE_TYPE, endpoint);
        var result = client.update(service);

        assertThat(result).isFailed();
        verify(httpClient, never()).execute(any(Request.class), anyList(), any());
    }

    @Test
    void deleteById_shouldCallDeleteEndpoint() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success(""));

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isSucceeded();

        var requestCaptor = ArgumentCaptor.forClass(Request.class);
        verify(httpClient).execute(requestCaptor.capture(), anyList(), any());
        assertThat(requestCaptor.getValue().method()).isEqualTo("DELETE");
        assertThat(requestCaptor.getValue().url().queryParameter("serviceId")).isEqualTo(SERVICE_ID);
    }

    @Test
    void deleteById_shouldTolerate400_serviceNotInDid() {
        // 400 → success (service not in DID, idempotent)
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.success(""));

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isSucceeded();
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"", "   "})
    void deleteById_shouldValidateId(String id) {
        var result = client.deleteById(id);

        assertThat(result).isFailed();
        verify(httpClient, never()).execute(any(Request.class), anyList(), any());
    }

    @Test
    void deleteById_shouldFailOnServerError() {
        when(httpClient.execute(any(Request.class), anyList(), any()))
                .thenReturn(Result.failure("Server error"));

        var result = client.deleteById(SERVICE_ID);

        assertThat(result).isFailed();
    }
}
